#include "mex.h"
#include <queue>
#include <vector>
#include <cmath>
#include <climits>
#include <functional>  // 添加 functional 头文件
#include <utility>     // 添加 utility 头文件

using namespace std;

struct Node {
    long x;
    long y;
    double dist;
    Node(long x, long y, double d) : x(x), y(y), dist(d) {}
    bool operator>(const Node& rhs) const { return dist > rhs.dist; }
};

// 8个移动方向：上、下、左、右、左上、右上、左下、右下
const int dx[8] = {0, 0, -1, 1, -1, 1, -1, 1};
const int dy[8] = {-1, 1, 0, 0, -1, -1, 1, 1};
// 使用 sqrt(2.0) 替代 M_SQRT2 提高兼容性
const double weights[8] = {1.0, 1.0, 1.0, 1.0, sqrt(2.0), sqrt(2.0), sqrt(2.0), sqrt(2.0)};

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
    // 输入参数处理
    double *img = mxGetPr(prhs[0]);
    double *x = mxGetPr(prhs[1]);
    double *y = mxGetPr(prhs[2]);
    long s = static_cast<long>(mxGetScalar(prhs[3]));
    long t = static_cast<long>(mxGetScalar(prhs[4]));
    
    // 获取图像尺寸
    const size_t *dims = mxGetDimensions(prhs[0]);
    long rows = static_cast<long>(dims[0]); // 图像行数
    long cols = static_cast<long>(dims[1]); // 图像列数

    // 分配距离数组并初始化
    vector<double> dist(rows * cols, DBL_MAX);
    vector<pair<long, long>> prev(rows * cols, make_pair(-1, -1)); // 使用 make_pair
    
    // 起点坐标（0-based）
    long startX = static_cast<long>(x[s-1]);
    long startY = static_cast<long>(y[s-1]);
    long startIdx = startY + startX * rows;
    dist[startIdx] = 0;
    
    // 优先队列（最小堆）- 明确指定比较函数类型
    priority_queue<Node, vector<Node>, greater<Node>> pq;
    pq.push(Node(startX, startY, 0));

    // Dijkstra算法
    while (!pq.empty()) {
        Node node = pq.top();
        pq.pop();
        long curX = node.x;
        long curY = node.y;
        long curIdx = curY + curX * rows;
        
        // 跳过已处理的节点
        if (node.dist > dist[curIdx]) continue;
        
        // 如果找到终点则停止
        if (curX == static_cast<long>(x[t-1]) && 
            curY == static_cast<long>(y[t-1])) break;
            
        // 检查8个邻域点
        for (int i = 0; i < 8; ++i) {
            long nx = curX + dx[i];
            long ny = curY + dy[i];
            
            // 边界检查
            if (nx < 0 || nx >= cols || ny < 0 || ny >= rows) continue;
            
            long newIdx = ny + nx * rows;
            
            // 可通行性检查
            if (img[newIdx] != 1) continue;
            
            // 计算新距离
            double newDist = dist[curIdx] + weights[i];
            
            // 如果找到更短路径
            if (newDist < dist[newIdx]) {
                dist[newIdx] = newDist;
                prev[newIdx] = make_pair(curX, curY); // 使用 make_pair
                pq.push(Node(nx, ny, newDist));
            }
        }
    }

    // 回溯路径
    long endX = static_cast<long>(x[t-1]);
    long endY = static_cast<long>(y[t-1]);
    long curX = endX, curY = endY;
    
    // 计算路径长度
    long pathLen = 0;
    while (!(curX == startX && curY == startY)) {
        pathLen++;
        long idx = curY + curX * rows;
        // 检查是否到达起点
        if (prev[idx].first == -1 && prev[idx].second == -1) break;
        curX = prev[idx].first;
        curY = prev[idx].second;
    }
    pathLen++; // 包含起点

    // 创建输出路径数组
    plhs[0] = mxCreateDoubleMatrix(1, pathLen, mxREAL);
    plhs[1] = mxCreateDoubleMatrix(1, pathLen, mxREAL);
    double *xs = mxGetPr(plhs[0]);
    double *ys = mxGetPr(plhs[1]);
    
    // 从终点回溯填充路径
    curX = endX;
    curY = endY;
    for (long pos = pathLen - 1; pos >= 0; --pos) {
        xs[pos] = static_cast<double>(curX);
        ys[pos] = static_cast<double>(curY);
        
        if (pos > 0) {
            long idx = curY + curX * rows;
            curX = prev[idx].first;
            curY = prev[idx].second;
        }
    }
}