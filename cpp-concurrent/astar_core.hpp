#ifndef ASTAR_CORE_HPP
#define ASTAR_CORE_HPP

#include <vector>

using namespace std;

// A grid position is represented by row and column.
struct Position {
    int row;
    int col;
};

// A node stores the information A* needs while searching.
//
// position: current cell
// g: cost already spent from the start
// h: estimated cost to the goal
// f: total score, calculated as g + h
// parent: index of the previous node in the closed list
struct Node {
    Position position;
    int g;
    int h;
    int f;
    int parent;
};

// Result returned by one A* search.
struct SearchResult {
    bool success;
    vector<Position> visited;
    vector<Position> path;
};

bool samePosition(Position a, Position b);
int manhattan(Position a, Position b);
bool insideGrid(const vector<vector<int>>& grid, Position position);
bool walkable(const vector<vector<int>>& grid, Position position);
vector<Position> neighbors(const vector<vector<int>>& grid, Position position);
SearchResult astar(const vector<vector<int>>& grid, Position start, Position goal);

#endif
