// 版本2
// #include "mex.h"
// #include <stdlib.h>
// #include <math.h>
// 
// struct point {
//     long x;
//     long y;
//     struct point* next;
// };
// 
// void mexFunction(int nlhs, mxArray* plhs[], int nrhs, const mxArray* prhs[]) {
//     // 输入参数获取
//     double* img = mxGetPr(prhs[0]);
//     double* x = mxGetPr(prhs[1]);
//     double* y = mxGetPr(prhs[2]);
//     long s = (long)mxGetScalar(prhs[3]);
//     long t = (long)mxGetScalar(prhs[4]);
// 
//     // 图像尺寸获取
//     const size_t* dims = mxGetDimensions(prhs[0]);
//     long rows = (long)dims[0];
//     long cols = (long)dims[1];
//     long total_pixels = rows * cols;
// 
//     // 分配距离数组并初始化
//     double* dist = (double*)malloc(total_pixels * sizeof(double));
//     for (long i = 0; i < total_pixels; i++) {
//         dist[i] = total_pixels; // 初始化为大数
//     }
// 
//     // 起点终点坐标（0-based）
//     long start_x = (long)x[s - 1];
//     long start_y = (long)y[s - 1];
//     long end_x = (long)x[t - 1];
//     long end_y = (long)y[t - 1];
// 
//     // 起点终点相同情况处理
//     if (start_x == end_x && start_y == end_y) {
//         plhs[0] = mxCreateDoubleMatrix(1, 1, mxREAL);
//         plhs[1] = mxCreateDoubleMatrix(1, 1, mxREAL);
//         double* outx = mxGetPr(plhs[0]);
//         double* outy = mxGetPr(plhs[1]);
//         outx[0] = start_x + 1; // 转回1-based
//         outy[0] = start_y + 1;
//         free(dist);
//         return;
//     }
// 
//     // 初始化队列
//     struct point* head = (struct point*)malloc(sizeof(struct point));
//     head->x = start_x;
//     head->y = start_y;
//     head->next = NULL;
//     struct point* tail = head;
// 
//     // 起点初始化
//     long start_idx = start_y + start_x * rows;
//     dist[start_idx] = 0;
// 
//     // BFS主循环
//     int found = 0;
//     while (head != NULL) {
//         long cur_x = head->x;
//         long cur_y = head->y;
//         long cur_idx = cur_y + cur_x * rows;
// 
//         // 检查是否到达终点
//         if (cur_x == end_x && cur_y == end_y) {
//             found = 1;
//             break;
//         }
// 
//         // 处理8邻域
//         for (int dx = -1; dx <= 1; dx++) {
//             for (int dy = -1; dy <= 1; dy++) {
//                 if (dx == 0 && dy == 0) continue;
// 
//                 long nx = cur_x + dx;
//                 long ny = cur_y + dy;
// 
//                 // 边界检查
//                 if (nx < 0 || nx >= cols || ny < 0 || ny >= rows) 
//                     continue;
// 
//                 long nidx = ny + nx * rows;
// 
//                 // 检查是否可通过且未访问
//                 if (img[nidx] == 1 && dist[nidx] == total_pixels) {
//                     dist[nidx] = dist[cur_idx] + 1;
// 
//                     // 加入队列
//                     struct point* new_node = (struct point*)malloc(sizeof(struct point));
//                     new_node->x = nx;
//                     new_node->y = ny;
//                     new_node->next = NULL;
// 
//                     tail->next = new_node;
//                     tail = new_node;
//                 }
//             }
//         }
// 
//         // 移除当前节点
//         struct point* temp = head;
//         head = head->next;
//         free(temp);
//     }
// 
//     // 终点未访问处理
//     long end_idx = end_y + end_x * rows;
//     if (!found || dist[end_idx] >= total_pixels) {
//         free(dist);
//         if (head) {
//             while (head) {
//                 struct point* temp = head;
//                 head = head->next;
//                 free(temp);
//             }
//         }
//         mexErrMsgIdAndTxt("BFS:NoPath", "No valid path found");
//     }
// 
//     // 清理剩余队列
//     while (head) {
//         struct point* temp = head;
//         head = head->next;
//         free(temp);
//     }
// 
//     // 回溯路径
//     long path_len = (long)dist[end_idx] + 1;
//     plhs[0] = mxCreateDoubleMatrix(1, path_len, mxREAL);
//     plhs[1] = mxCreateDoubleMatrix(1, path_len, mxREAL);
//     double* outx = mxGetPr(plhs[0]);
//     double* outy = mxGetPr(plhs[1]);
// 
//     // 设置终点
//     long cur_x = end_x;
//     long cur_y = end_y;
//     outx[path_len - 1] = cur_x;
//     outy[path_len - 1] = cur_y;
// 
//     // 回溯过程
//     for (long i = path_len - 2; i >= 0; i--) {
//         long cur_idx = cur_y + cur_x * rows;
//         double min_dist = dist[cur_idx];
//         long next_x = cur_x;
//         long next_y = cur_y;
// 
//         // 在8邻域中寻找前驱节点
//         for (int dx = -1; dx <= 1; dx++) {
//             for (int dy = -1; dy <= 1; dy++) {
//                 if (dx == 0 && dy == 0) continue;
// 
//                 long nx = cur_x + dx;
//                 long ny = cur_y + dy;
// 
//                 // 边界检查
//                 if (nx < 0 || nx >= cols || ny < 0 || ny >= rows) 
//                     continue;
// 
//                 long nidx = ny + nx * rows;
// 
//                 // 找到更小距离的相邻点
//                 if (dist[nidx] < min_dist) {
//                     min_dist = dist[nidx];
//                     next_x = nx;
//                     next_y = ny;
//                 }
//             }
//         }
// 
//         // 设置路径点
//         outx[i] = next_x;
//         outy[i] = next_y;
//         cur_x = next_x;
//         cur_y = next_y;
//     }
// 
//     // 释放内存
//     free(dist);
// }

// #include "mex.h"
// #include <stdlib.h>
// #include <math.h>
// #include <cstring>
// 
// struct point {
//     long x;
//     long y;
//     struct point* next;
// };
// 
// void mexFunction(int nlhs, mxArray* plhs[], int nrhs, const mxArray* prhs[]) {
//     double* img = mxGetPr(prhs[0]);
//     double* x = mxGetPr(prhs[1]);
//     double* y = mxGetPr(prhs[2]);
//     long s = (long)mxGetScalar(prhs[3]);
//     long t = (long)mxGetScalar(prhs[4]);
//     double* imgproj_DT = mxGetPr(prhs[5]);
//     double* img_DT = mxGetPr(prhs[6]);
//     plhs[2] = mxCreateDoubleScalar(1);
// 
//     long nn=0;
// 
//     const size_t* dims = mxGetDimensions(prhs[0]);
//     long rows = (long)dims[0];
//     long cols = (long)dims[1];
//     long total_pixels = rows * cols;
// 
//     double* dist = (double*)malloc(total_pixels * sizeof(double));
//     long *step = (long*)malloc(total_pixels * sizeof(long));
// 
// 
// 
//     for (long i = 0; i < total_pixels; i++) {
//         dist[i] = total_pixels; // 初始化为大数
//         step[i] = -1;
//     }
// 
//     for (long i = 0; i < total_pixels; i++) {
//         if (imgproj_DT[i] <= 2 && img[i] == 0){
//             img[i] = 5;
//         } 
//     } 
// 
// 
//     long start_x = (long)x[s - 1];
//     long start_y = (long)y[s - 1];
//     long end_x = (long)x[t - 1];
//     long end_y = (long)y[t - 1];
// 
//     // 起点终点相同情况处理
//     if (start_x == end_x && start_y == end_y) {
//         plhs[0] = mxCreateDoubleMatrix(1, 1, mxREAL);
//         plhs[1] = mxCreateDoubleMatrix(1, 1, mxREAL);
//         double* outx = mxGetPr(plhs[0]);
//         double* outy = mxGetPr(plhs[1]);
//         outx[0] = start_x + 1; // 转回1-based
//         outy[0] = start_y + 1;
//         free(dist);
//         return;
//     }
// 
//     // 初始化队列
//     struct point* head = (struct point*)malloc(sizeof(struct point));
//     head->x = start_x;
//     head->y = start_y;
//     head->next = NULL;
//     struct point* tail = head;
// 
//     // 起点初始化
//     long start_idx = start_y + start_x * rows;
//     dist[start_idx] = 0;
//     step[start_idx] = 0;
// 
//     int found = 0;
//     while(head!=NULL){
//         long cur_x = head->x;
//         long cur_y = head->y;
//         long cur_idx = cur_y + cur_x * rows;
// 
//         // 检查是否到达终点
//         if (cur_x == end_x && cur_y == end_y) {
//             found = 1;
//             // continue;
//         }
// 
//          for (int dx = -1; dx <= 1; dx++) {
//             for (int dy = -1; dy <= 1; dy++) {
//                 if (dx==0&&dy==0)continue;
//                 long nx = cur_x + dx;
//                 long ny = cur_y + dy;
//                 long nidx = ny + nx * rows;
//                 // 边界检查
//                 if (nx < 0 || nx >= cols || ny < 0 || ny >= rows) continue;
//                 if (imgproj_DT[nidx]>40)continue;
//                 // 检查是否可通过且未访问 //dist[cur_idx] + 0.5*imgproj_DT[nidx] + img[nidx] +img_DT[nidx]
//                 if (img[nidx]!=0 && dist[cur_idx] + 1.2*imgproj_DT[nidx] + img[nidx]< dist[nidx]) {
//                     dist[nidx] = dist[cur_idx] + 1.2*imgproj_DT[nidx] + img[nidx];
//                     step[nidx] = step[cur_idx] + 1;
// 
//                     // 加入队列
//                     struct point* new_node = (struct point*)malloc(sizeof(struct point));
//                     new_node->x = nx;
//                     new_node->y = ny;
//                     new_node->next = NULL;
// 
//                     tail->next = new_node;
//                     tail = new_node;
//                 }    
//             }
//          }
//         // 移除当前节点
//         struct point* temp = head;
//         head = head->next;
//         free(temp);
//     }
// 
//     // 终点未访问处理
//     long end_idx = end_y + end_x * rows;
//     if (!found || dist[end_idx] >= total_pixels) {
//         free(dist);
//         plhs[0] = mxCreateDoubleMatrix(0, 0, mxREAL);
//         plhs[1] = mxCreateDoubleMatrix(0, 0, mxREAL);
//         plhs[2] = mxCreateDoubleScalar(0);      
//         if (head) {
//             while (head) {
//                 struct point* temp = head;
//                 head = head->next;
//                 free(temp);
//             }
//         }
//         return;
//         mexErrMsgIdAndTxt("BFS:NoPath", "No valid path found");
// 
// 
//     }
// 
//     // 清理剩余队列
//     while (head) {
//         struct point* temp = head;
//         head = head->next;
//         free(temp);
//     }
// 
//     // 回溯
//     long path_len = (long)step[end_idx] + 1;//包含起点+1
//     plhs[0] = mxCreateDoubleMatrix(1, path_len, mxREAL);
//     plhs[1] = mxCreateDoubleMatrix(1, path_len, mxREAL);
//     double* outx = mxGetPr(plhs[0]);
//     double* outy = mxGetPr(plhs[1]);
// 
//     // 设置终点
//     long cur_x = end_x;
//     long cur_y = end_y;
//     outx[path_len - 1] = cur_x;
//     outy[path_len - 1] = cur_y;
// 
//     for (long i = path_len - 2; i >= 0; i--) {
//         long cur_idx = cur_y + cur_x * rows;
//         double min_dist = dist[cur_idx];
//         long next_x = cur_x;
//         long next_y = cur_y;
// 
//         for(int dx = -1; dx <= 1; dx++){
//             for(int dy = -1; dy <= 1; dy++){
//                 if (dx == 0 && dy == 0) continue;
//                 long nx = cur_x + dx;
//                 long ny = cur_y + dy;
//                 long nidx = ny + nx * rows;
//                 // 边界检查
//                 if (nx < 0 || nx >= cols || ny < 0 || ny >= rows) continue;
// 
//                 // 找到更小距离的相邻点
//                 //!!!!bug,若只按projimg_DT累计dist值，会导致一部分区域dist值不变，从而导致回溯中断
//                 if (dist[nidx] < min_dist) {
//                     min_dist = dist[nidx];
//                     next_x = nx;
//                     next_y = ny;
//                 }
//             }
//         }
//         // 设置路径点
//         outx[i] = next_x;
//         outy[i] = next_y;
//         cur_x = next_x;
//         cur_y = next_y;
// 
//     }
//     // 释放内存
//     free(dist);
// }



#include "mex.h"
#include <cstdlib>
#include <cmath>
#include <cstring>

struct point {
    long x;
    long y;
    point* next;
};

static void free_queue(point* head) {
    while (head) {
        point* tmp = head;
        head = head->next;
        free(tmp);
    }
}

void mexFunction(int nlhs, mxArray* plhs[], int nrhs, const mxArray* prhs[]) {
    if (nrhs < 7) {
        mexErrMsgIdAndTxt("shortestway2d:args", "Need 7 inputs.");
    }
    if (nlhs < 3) {
        mexErrMsgIdAndTxt("shortestway2d:outs", "Need 3 outputs.");
    }

    const mxArray* img_in = prhs[0];
    const double* img0 = mxGetPr(img_in);           // 输入只读
    const double* x = mxGetPr(prhs[1]);
    const double* y = mxGetPr(prhs[2]);
    long s = (long)mxGetScalar(prhs[3]);
    long t = (long)mxGetScalar(prhs[4]);
    const double* imgproj_DT = mxGetPr(prhs[5]);
    const double* img_DT = mxGetPr(prhs[6]);

    const mwSize* dims = mxGetDimensions(img_in);
    long rows = (long)dims[0];
    long cols = (long)dims[1];
    long total_pixels = rows * cols;

    // ---- 本地拷贝 img（如果你必须改它）----
    // 如果你其实不必修改img，可以把下面这段删掉，并改用 img0
    double* img = (double*)mxMalloc((size_t)total_pixels * sizeof(double));
    if (!img) mexErrMsgIdAndTxt("shortestway2d:oom", "mxMalloc img failed.");
    std::memcpy(img, img0, (size_t)total_pixels * sizeof(double));

    // ---- 分配 dist / step（用 mxMalloc，便于 MATLAB 管理）----
    double* dist = (double*)mxMalloc((size_t)total_pixels * sizeof(double));
    long* step   = (long*)mxMalloc((size_t)total_pixels * sizeof(long));
    if (!dist || !step) {
        if (dist) mxFree(dist);
        if (step) mxFree(step);
        mxFree(img);
        mexErrMsgIdAndTxt("shortestway2d:oom", "mxMalloc dist/step failed.");
    }

    for (long i = 0; i < total_pixels; i++) {
        dist[i] = (double)total_pixels;
        step[i] = -1;
    }

    // 你原来的“改img”逻辑，现在是改本地 img，不会破坏输入
    for (long i = 0; i < total_pixels; i++) {
        if (imgproj_DT[i] <= 2 && img[i] == 0) img[i] = 5;
    }

    long start_x = (long)x[s - 1];
    long start_y = (long)y[s - 1];
    long end_x   = (long)x[t - 1];
    long end_y   = (long)y[t - 1];

    // 起点终点相同
    if (start_x == end_x && start_y == end_y) {
        plhs[0] = mxCreateDoubleMatrix(1, 1, mxREAL);
        plhs[1] = mxCreateDoubleMatrix(1, 1, mxREAL);
        plhs[2] = mxCreateDoubleScalar(1);
        double* outx = mxGetPr(plhs[0]);
        double* outy = mxGetPr(plhs[1]);
        outx[0] = start_x + 1;
        outy[0] = start_y + 1;

        mxFree(dist);
        mxFree(step);
        mxFree(img);
        return;
    }

    // 队列
    point* head = (point*)mxMalloc(sizeof(point));
    if (!head) {
        mxFree(dist); mxFree(step); mxFree(img);
        mexErrMsgIdAndTxt("shortestway2d:oom", "mxMalloc queue head failed.");
    }
    head->x = start_x; head->y = start_y; head->next = NULL;
    point* tail = head;

    long start_idx = start_y + start_x * rows;
    dist[start_idx] = 0;
    step[start_idx] = 0;

    int found = 0;

    while (head != NULL) {
        long cur_x = head->x;
        long cur_y = head->y;
        long cur_idx = cur_y + cur_x * rows;

        if (cur_x == end_x && cur_y == end_y) found = 1;

        for (int dx = -1; dx <= 1; dx++) {
            for (int dy = -1; dy <= 1; dy++) {
                if (dx==0 && dy==0) continue;
                long nx = cur_x + dx;
                long ny = cur_y + dy;

                // 先边界检查
                if (nx < 0 || nx >= cols || ny < 0 || ny >= rows) continue;

                long nidx = ny + nx * rows;

                if (imgproj_DT[nidx] > 40) continue; // 原来break -> continue

                if (img[nidx] != 0) {
                    double cand = dist[cur_idx] + 0.2*imgproj_DT[nidx] + img[nidx];
                    if (cand < dist[nidx]) {
                        dist[nidx] = cand;
                        step[nidx] = step[cur_idx] + 1;

                        point* new_node = (point*)mxMalloc(sizeof(point));
                        if (!new_node) {
                            free_queue(head);
                            mxFree(dist); mxFree(step); mxFree(img);
                            mexErrMsgIdAndTxt("shortestway2d:oom", "mxMalloc queue node failed.");
                        }
                        new_node->x = nx; new_node->y = ny; new_node->next = NULL;
                        tail->next = new_node;
                        tail = new_node;
                    }
                }
            }
        }

        point* temp = head;
        head = head->next;
        mxFree(temp);
    }

    long end_idx = end_y + end_x * rows;
    if (!found || dist[end_idx] >= total_pixels) {
        plhs[0] = mxCreateDoubleMatrix(0, 0, mxREAL);
        plhs[1] = mxCreateDoubleMatrix(0, 0, mxREAL);
        plhs[2] = mxCreateDoubleScalar(0);

        mxFree(dist);
        mxFree(step);
        mxFree(img);
        return;
    }

    long path_len = step[end_idx] + 1;
    plhs[0] = mxCreateDoubleMatrix(1, path_len, mxREAL);
    plhs[1] = mxCreateDoubleMatrix(1, path_len, mxREAL);
    plhs[2] = mxCreateDoubleScalar(1);

    double* outx = mxGetPr(plhs[0]);
    double* outy = mxGetPr(plhs[1]);

    long cur_x = end_x, cur_y = end_y;
    outx[path_len - 1] = cur_x;
    outy[path_len - 1] = cur_y;

    for (long i = path_len - 2; i >= 0; i--) {
        long cur_idx = cur_y + cur_x * rows;
        double min_dist = dist[cur_idx];
        long next_x = cur_x, next_y = cur_y;

        for (int dx = -1; dx <= 1; dx++) {
            for (int dy = -1; dy <= 1; dy++) {
                if (dx==0 && dy==0) continue;
                long nx = cur_x + dx;
                long ny = cur_y + dy;
                if (nx < 0 || nx >= cols || ny < 0 || ny >= rows) continue;
                long nidx = ny + nx * rows;

                if (dist[nidx] < min_dist) {
                    min_dist = dist[nidx];
                    next_x = nx; next_y = ny;
                }
            }
        }
        outx[i] = next_x;
        outy[i] = next_y;
        cur_x = next_x;
        cur_y = next_y;
    }

    mxFree(dist);
    mxFree(step);
    mxFree(img);
}
