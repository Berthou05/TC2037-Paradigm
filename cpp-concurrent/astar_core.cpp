#include "astar_core.hpp"

#include <algorithm>
#include <cstdlib>

using namespace std;

// Positions are equal when both their row and column match.
bool samePosition(Position a, Position b) {
    return a.row == b.row && a.col == b.col;
}

// Manhattan distance is the heuristic used by A*.
// It fits this grid because movement is only up, down, left and right.
int manhattan(Position a, Position b) {
    return abs(a.row - b.row) + abs(a.col - b.col);
}

// A position is inside the grid if row and column are valid indices.
bool insideGrid(const vector<vector<int>>& grid, Position position) {
    return position.row >= 0
        && position.col >= 0
        && position.row < (int)grid.size()
        && position.col < (int)grid[0].size();
}

// A cell is walkable when it is inside the grid and its value is 0.
bool walkable(const vector<vector<int>>& grid, Position position) {
    return insideGrid(grid, position)
        && grid[position.row][position.col] == 0;
}

// Generate the valid neighboring positions for one cell.
// At most four candidates are checked, so this is constant work per node.
vector<Position> neighbors(const vector<vector<int>>& grid, Position position) {
    vector<Position> result;
    vector<Position> directions = {
        {-1, 0},
        {1, 0},
        {0, -1},
        {0, 1}
    };

    for (Position direction : directions) {
        Position candidate = {
            position.row + direction.row,
            position.col + direction.col
        };

        if (walkable(grid, candidate)) {
            result.push_back(candidate);
        }
    }

    return result;
}

// Find a node by position inside a list.
// This is a linear scan, matching the simple list-based Racket version.
int findByPosition(const vector<Node>& nodes, Position position) {
    for (int i = 0; i < (int)nodes.size(); i++) {
        if (samePosition(nodes[i].position, position)) {
            return i;
        }
    }

    return -1;
}

// Select the frontier node with the lowest f value.
// If two nodes tie, the one with lower h is preferred.
int bestNodeIndex(const vector<Node>& frontier) {
    int best = 0;

    for (int i = 1; i < (int)frontier.size(); i++) {
        bool lowerF = frontier[i].f < frontier[best].f;
        bool sameFBetterH = frontier[i].f == frontier[best].f
            && frontier[i].h < frontier[best].h;

        if (lowerF || sameFBetterH) {
            best = i;
        }
    }

    return best;
}

// Rebuild the path by following parent indices from goal to start.
vector<Position> reconstructPath(vector<Node> closedNodes, int currentIndex) {
    vector<Position> path;

    while (currentIndex != -1) {
        Node current = closedNodes[currentIndex];
        path.push_back(current.position);
        currentIndex = current.parent;
    }

    reverse(path.begin(), path.end());
    return path;
}

// Main A* implementation.
//
// The frontier and closed list are vectors used like simple lists.
// This keeps the implementation close to the Racket version and easier
// to inspect, even though a priority queue would be faster.
SearchResult astar(const vector<vector<int>>& grid, Position start, Position goal) {
    vector<Node> frontier;
    vector<Node> closedNodes;

    if (!walkable(grid, start) || !walkable(grid, goal)) {
        return {false, {}, {}};
    }

    int h = manhattan(start, goal);
    frontier.push_back({start, 0, h, h, -1});

    while (!frontier.empty()) {
        int best = bestNodeIndex(frontier);
        Node current = frontier[best];
        frontier.erase(frontier.begin() + best);

        int currentClosedIndex = (int)closedNodes.size();
        closedNodes.push_back(current);

        if (samePosition(current.position, goal)) {
            vector<Position> visited;
            for (Node node : closedNodes) {
                visited.push_back(node.position);
            }

            return {true, visited, reconstructPath(closedNodes, currentClosedIndex)};
        }

        for (Position neighbor : neighbors(grid, current.position)) {
            if (findByPosition(closedNodes, neighbor) != -1) {
                continue;
            }

            int newG = current.g + 1;
            int newH = manhattan(neighbor, goal);
            Node candidate = {neighbor, newG, newH, newG + newH, currentClosedIndex};

            int existing = findByPosition(frontier, neighbor);
            if (existing == -1) {
                frontier.push_back(candidate);
            } else if (candidate.g < frontier[existing].g) {
                frontier[existing] = candidate;
            }
        }
    }

    vector<Position> visited;
    for (Node node : closedNodes) {
        visited.push_back(node.position);
    }

    return {false, visited, {}};
}
