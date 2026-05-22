#include "astar_core.hpp"

#include <iostream>
#include <mutex>
#include <random>
#include <string>
#include <thread>
#include <vector>

using namespace std;

// This file is the C++ concurrent driver.
//
// The actual A* algorithm is in astar_core.cpp. This file only handles:
// - grid generation
// - launching several A* searches with threads
// - collecting results safely with a mutex
// - printing JSON for the React visualizer

mutex resultMutex;

// Create a random grid where 0 is free and 1 is an obstacle.
// The start and goal cells are kept free.
vector<vector<int>> generateRandomGrid(int rows, int cols, double density, mt19937& gen) {
    uniform_real_distribution<double> chance(0.0, 1.0);
    vector<vector<int>> grid(rows, vector<int>(cols, 0));

    for (int row = 0; row < rows; row++) {
        for (int col = 0; col < cols; col++) {
            bool isStart = row == 0 && col == 0;
            bool isGoal = row == rows - 1 && col == cols - 1;
            grid[row][col] = (!isStart && !isGoal && chance(gen) < density) ? 1 : 0;
        }
    }

    return grid;
}

void openCell(vector<vector<int>>& grid, Position position) {
    grid[position.row][position.col] = 0;
}

// Build a random route through waypoints.
// This is used only to guarantee that "Require valid path" has at least
// one open route in the generated grid.
vector<Position> randomWaypointPath(int rows, int cols, mt19937& gen) {
    uniform_int_distribution<int> waypointCount(2, 4);
    uniform_int_distribution<int> rowDist(0, rows - 1);
    uniform_int_distribution<int> colDist(0, cols - 1);
    uniform_int_distribution<int> pickDirection(0, 1);

    vector<Position> waypoints;
    waypoints.push_back({0, 0});

    int count = waypointCount(gen);
    for (int i = 0; i < count; i++) {
        waypoints.push_back({rowDist(gen), colDist(gen)});
    }

    waypoints.push_back({rows - 1, cols - 1});

    vector<Position> path;
    path.push_back(waypoints[0]);

    for (int i = 0; i < (int)waypoints.size() - 1; i++) {
        Position current = waypoints[i];
        Position target = waypoints[i + 1];

        while (!samePosition(current, target)) {
            bool canMoveVertical = current.row != target.row;
            bool canMoveHorizontal = current.col != target.col;
            bool moveVertical = canMoveVertical
                && (!canMoveHorizontal || pickDirection(gen) == 0);

            if (moveVertical) {
                current.row += current.row < target.row ? 1 : -1;
            } else {
                current.col += current.col < target.col ? 1 : -1;
            }

            path.push_back(current);
        }
    }

    return path;
}

// Apply the visualizer path mode to the generated grid.
// random: may or may not contain a path
// solvable: opens a guaranteed waypoint route
// blocked: isolates the start so no path can exist
vector<vector<int>> generateGrid(int rows, int cols, double density, string mode) {
    random_device rd;
    mt19937 gen(rd());
    vector<vector<int>> grid = generateRandomGrid(rows, cols, density, gen);

    if (mode == "solvable") {
        vector<Position> path = randomWaypointPath(rows, cols, gen);
        for (Position position : path) {
            openCell(grid, position);
        }
    }

    if (mode == "blocked") {
        grid[0][0] = 0;
        grid[rows - 1][cols - 1] = 0;
        grid[0][1] = 1;
        grid[1][0] = 1;
    }

    return grid;
}

// Run one A* search in one thread.
// The grid is shared read-only, and each thread writes only one result slot.
void runAgent(
    int index,
    const vector<vector<int>>& grid,
    Position start,
    Position goal,
    vector<SearchResult>& results
) {
    SearchResult result = astar(grid, start, goal);
    lock_guard<mutex> lock(resultMutex);
    results[index] = result;
}

void writePositionsJson(const vector<Position>& positions) {
    cout << "[";
    for (int i = 0; i < (int)positions.size(); i++) {
        if (i > 0) {
            cout << ",";
        }
        cout << "[" << positions[i].row << "," << positions[i].col << "]";
    }
    cout << "]";
}

void writeGridJson(const vector<vector<int>>& grid) {
    cout << "[";
    for (int row = 0; row < (int)grid.size(); row++) {
        if (row > 0) {
            cout << ",";
        }
        cout << "[";
        for (int col = 0; col < (int)grid[row].size(); col++) {
            if (col > 0) {
                cout << ",";
            }
            cout << grid[row][col];
        }
        cout << "]";
    }
    cout << "]";
}

// Print one JSON object using the same shape consumed by the visualizer.
// The main visual path is agent 1. The agents array summarizes the
// concurrent searches.
void writeResultJson(
    const vector<vector<int>>& grid,
    Position start,
    Position goal,
    const SearchResult& mainResult,
    const vector<SearchResult>& agentResults
) {
    cout << "{";
    cout << "\"backend\":\"cpp\",";
    cout << "\"success\":" << (mainResult.success ? "true" : "false") << ",";
    cout << "\"grid\":";
    writeGridJson(grid);
    cout << ",\"start\":[" << start.row << "," << start.col << "],";
    cout << "\"goal\":[" << goal.row << "," << goal.col << "],";
    cout << "\"visited\":";
    writePositionsJson(mainResult.visited);
    cout << ",\"path\":";
    writePositionsJson(mainResult.path);
    cout << ",\"agents\":[";
    for (int i = 0; i < (int)agentResults.size(); i++) {
        if (i > 0) {
            cout << ",";
        }
        cout << "{\"id\":" << (i + 1) << ",\"success\":"
             << (agentResults[i].success ? "true" : "false")
             << ",\"pathLength\":" << agentResults[i].path.size() << "}";
    }
    cout << "]}";
}

int main(int argc, char* argv[]) {
    int rows = argc > 1 ? stoi(argv[1]) : 10;
    int cols = argc > 2 ? stoi(argv[2]) : 10;
    double density = argc > 3 ? stod(argv[3]) : 0.3;
    string mode = argc > 4 ? argv[4] : "random";

    Position start = {0, 0};
    Position goal = {rows - 1, cols - 1};
    vector<vector<int>> grid = generateGrid(rows, cols, density, mode);

    vector<Position> starts = {
        start,
        {0, cols - 1},
        {rows - 1, 0}
    };

    vector<Position> goals = {
        goal,
        {rows - 1, 0},
        {0, cols - 1}
    };

    vector<SearchResult> results(starts.size());
    vector<thread> threads;

    for (int i = 0; i < (int)starts.size(); i++) {
        threads.push_back(thread(runAgent, i, cref(grid), starts[i], goals[i], ref(results)));
    }

    for (int i = 0; i < (int)threads.size(); i++) {
        threads[i].join();
    }

    writeResultJson(grid, start, goal, results[0], results);
    cout << endl;

    return 0;
}
