#include "mex.h"
#include <stdlib.h>
#include <math.h>
#include <cstring>

struct point {
    long x;
    long y;
    struct point* next;
};

void mexFunction(int nlhs, mxArray* plhs[], int nrhs, const mxArray* prhs[]) {
    double* img = mxGetPr(prhs[0]);
    double* x = mxGetPr(prhs[1]);
    double* y = mxGetPr(prhs[2]);
    long s = (long)mxGetScalar(prhs[3]);
    long t = (long)mxGetScalar(prhs[4]);
    double* imgproj_DT = mxGetPr(prhs[5]);
    double* img_DT = mxGetPr(prhs[6])
    plhs[2] = mxCreateDoubleScalar(1);

    long nn=0;

    const size_t* dims = mxGetDimensions(prhs[0]);
    long rows = (long)dims[0];
    long cols = (long)dims[1];
    long total_pixels = rows * cols;

    double* dist = (double*)malloc(total_pixels * sizeof(double));
    long *step = (long*)malloc(total_pixels * sizeof(long));



    for (long i = 0; i < total_pixels; i++) {
        dist[i] = total_pixels; // 初始化为大数
        step[i] = -1;
    }

    for (long i = 0; i < total_pixels; i++) {
        if (imgproj_DT[i] <= 6 && img[i] == 0){
            img[i] = 2.6;
        } 
    } 


    long start_x = (long)x[s - 1];
    long start_y = (long)y[s - 1];
    long end_x = (long)x[t - 1];
    long end_y = (long)y[t - 1];

    // 起点终点相同情况处理
    if (start_x == end_x && start_y == end_y) {
        plhs[0] = mxCreateDoubleMatrix(1, 1, mxREAL);
        plhs[1] = mxCreateDoubleMatrix(1, 1, mxREAL);
        double* outx = mxGetPr(plhs[0]);
        double* outy = mxGetPr(plhs[1]);
        outx[0] = start_x + 1; // 转回1-based
        outy[0] = start_y + 1;
        free(dist);
        return;
    }

    // 初始化队列
    struct point* head = (struct point*)malloc(sizeof(struct point));
    head->x = start_x;
    head->y = start_y;
    head->next = NULL;
    struct point* tail = head;

    // 起点初始化
    long start_idx = start_y + start_x * rows;
    dist[start_idx] = 0;
    step[start_idx] = 0;

    int found = 0;
    while(head!=NULL){
        long cur_x = head->x;
        long cur_y = head->y;
        long cur_idx = cur_y + cur_x * rows;

        // 检查是否到达终点
        if (cur_x == end_x && cur_y == end_y) {
            found = 1;
            // continue;
        }

         for (int dx = -1; dx <= 1; dx++) {
            for (int dy = -1; dy <= 1; dy++) {
                if (dx==0&&dy==0)continue;
                long nx = cur_x + dx;
                long ny = cur_y + dy;
                long nidx = ny + nx * rows;
                // 边界检查
                if (nx < 0 || nx >= cols || ny < 0 || ny >= rows) continue;
                // 检查是否可通过且未访问
                if (dist[cur_idx] + imgproj_DT[nidx] + img_DT[nidx] + img[nidx]< dist[nidx]) {
                    dist[nidx] = dist[cur_idx] + imgproj_DT[nidx] + img_DT[nidx] + img[nidx];
                    step[nidx] = step[cur_idx] + 1;

                    // 加入队列
                    struct point* new_node = (struct point*)malloc(sizeof(struct point));
                    new_node->x = nx;
                    new_node->y = ny;
                    new_node->next = NULL;

                    tail->next = new_node;
                    tail = new_node;
                }    
            }
         }
        // 移除当前节点
        struct point* temp = head;
        head = head->next;
        free(temp);
    }

    // 终点未访问处理
    long end_idx = end_y + end_x * rows;
    if (!found || dist[end_idx] >= total_pixels) {
        free(dist);
        plhs[0] = mxCreateDoubleMatrix(0, 0, mxREAL);
        plhs[1] = mxCreateDoubleMatrix(0, 0, mxREAL);
        plhs[2] = mxCreateDoubleScalar(0);      
        if (head) {
            while (head) {
                struct point* temp = head;
                head = head->next;
                free(temp);
            }
        }

        mexErrMsgIdAndTxt("BFS:NoPath", "No valid path found");
        return;

    }

    // 清理剩余队列
    while (head) {
        struct point* temp = head;
        head = head->next;
        free(temp);
    }

    // 回溯
    long path_len = (long)step[end_idx] + 1;//包含起点+1
    plhs[0] = mxCreateDoubleMatrix(1, path_len, mxREAL);
    plhs[1] = mxCreateDoubleMatrix(1, path_len, mxREAL);
    double* outx = mxGetPr(plhs[0]);
    double* outy = mxGetPr(plhs[1]);

    // 设置终点
    long cur_x = end_x;
    long cur_y = end_y;
    outx[path_len - 1] = cur_x;
    outy[path_len - 1] = cur_y;

    for (long i = path_len - 2; i >= 0; i--) {
        long cur_idx = cur_y + cur_x * rows;
        double min_dist = dist[cur_idx];
        long next_x = cur_x;
        long next_y = cur_y;

        for(int dx = -1; dx <= 1; dx++){
            for(int dy = -1; dy <= 1; dy++){
                if (dx == 0 && dy == 0) continue;
                long nx = cur_x + dx;
                long ny = cur_y + dy;
                long nidx = ny + nx * rows;
                // 边界检查
                if (nx < 0 || nx >= cols || ny < 0 || ny >= rows) continue;

                // 找到更小距离的相邻点
                //!!!!bug,若只按projimg_DT累计dist值，会导致一部分区域dist值不变，从而导致回溯中断
                if (dist[nidx] < min_dist) {
                    min_dist = dist[nidx];
                    next_x = nx;
                    next_y = ny;
                }
            }
        }
        // 设置路径点
        outx[i] = next_x;
        outy[i] = next_y;
        cur_x = next_x;
        cur_y = next_y;

    }
    // 释放内存
    free(dist);
}