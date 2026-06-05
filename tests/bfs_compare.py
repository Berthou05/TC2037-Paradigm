import json
import subprocess
import sys
from collections import deque
from pathlib import Path


# Helper test script used to validate A* against the optimal path length.
# BFS is used only to calculate the perfect result for an unweighted grid.
# AI assistance was used to optimize and organize this testing helper.


LENGTH_THRESHOLD_PERCENT = 0


def inside_grid(grid, position):
    row, col = position
    return 0 <= row < len(grid) and 0 <= col < len(grid[0])


def walkable(grid, position):
    row, col = position
    return inside_grid(grid, position) and grid[row][col] == 0


def neighbors(grid, position):
    row, col = position
    candidates = [
        [row - 1, col],
        [row + 1, col],
        [row, col - 1],
        [row, col + 1],
    ]
    return [candidate for candidate in candidates if walkable(grid, candidate)]


def bfs_shortest_path(grid, start, goal):
    if not walkable(grid, start) or not walkable(grid, goal):
        return []

    queue = deque([[start, [start]]])
    visited = {tuple(start)}

    while queue:
        current, path = queue.popleft()

        if current == goal:
            return path

        for candidate in neighbors(grid, current):
            key = tuple(candidate)
            if key not in visited:
                visited.add(key)
                queue.append([candidate, path + [candidate]])

    return []


def valid_astar_path(grid, path, start, goal):
    if not path:
        return False
    if path[0] != start or path[-1] != goal:
        return False

    for position in path:
        if not walkable(grid, position):
            return False

    for left, right in zip(path, path[1:]):
        distance = abs(left[0] - right[0]) + abs(left[1] - right[1])
        if distance != 1:
            return False

    return True


def load_astar_results(racket_exe):
    script = Path(__file__).with_name("astar-case-runner.rkt")
    completed = subprocess.run(
        [str(racket_exe), str(script)],
        check=True,
        capture_output=True,
        text=True,
    )
    return json.loads(completed.stdout)


def main():
    racket_exe = sys.argv[1] if len(sys.argv) > 1 else "racket"
    results = load_astar_results(racket_exe)
    checked_cases = 0

    for result in results:
        grid = result["grid"]
        start = result["start"]
        goal = result["goal"]
        astar_success = result["success"]
        astar_path = result["path"]
        bfs_path = bfs_shortest_path(grid, start, goal)
        bfs_success = bool(bfs_path)

        if astar_success != bfs_success:
            raise AssertionError(
                f"{result['name']}: A* success={astar_success}, "
                f"optimal success={bfs_success}"
            )

        if astar_success:
            if not valid_astar_path(grid, astar_path, start, goal):
                raise AssertionError(f"{result['name']}: A* returned an invalid path")
            allowed_length = len(bfs_path) * (1 + LENGTH_THRESHOLD_PERCENT / 100)
            if len(astar_path) > allowed_length:
                raise AssertionError(
                    f"{result['name']}: A* length={len(astar_path)}, "
                    f"optimal length={len(bfs_path)}, "
                    f"threshold={LENGTH_THRESHOLD_PERCENT}%"
                )
            if len(astar_path) < len(bfs_path):
                raise AssertionError(
                    f"{result['name']}: A* length={len(astar_path)} is shorter than "
                    f"the optimal length={len(bfs_path)}, so one path calculation is inconsistent"
                )

        if not astar_success and astar_path:
            raise AssertionError(f"{result['name']}: failed search should return empty path")

        checked_cases += 1

    print(
        "Optimal-path validation tests passes "
        f"{checked_cases}/{len(results)} cases, {LENGTH_THRESHOLD_PERCENT}% threshold"
    )


if __name__ == "__main__":
    main()
