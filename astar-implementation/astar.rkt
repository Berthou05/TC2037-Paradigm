#lang racket

;;
;; A* PATHFINDING ALGORITHM - FUNCTIONAL IMPLEMENTATION
;;
;; This file contains the core A* algorithm using functional programming.
;; Each function transforms data (immutable) without modifying state.
;; The algorithm finds the shortest path from start to goal in a grid
;; while avoiding obstacles.
;;
;; Key concept: Treat the search as a sequence of data transformations.
;; No objects change internally. Instead, functions return new versions
;; of the frontier and visited lists with updated information.
;;

(provide (struct-out node)
         sample-grid
         sample-start
         sample-goal
         directions
         inside-grid?
         walkable?
         valid-position?
         neighbors
         manhattan
         make-node
         best-node
         remove-node
         reconstruct-path
         a-star)

;;
;; ==================== DATA STRUCTURE ====================
;;

;; Node: represents one position in the A* search with scoring info.
;;
;; Fields:
;;   position: [row col] - location on grid
;;   g: real cost from start to this node
;;   h: estimated cost from this node to goal (heuristic)
;;   f: total estimated cost (f = g + h)
;;   parent: previous node in path (for reconstruction)
;;
;; Why this structure?
;; A* needs to compare nodes by f score and later reconstruct the path.
;; Bundling these together keeps the algorithm focused.
(struct node (position g h f parent) #:transparent)

;;
;; Sample grid for testing and demonstration.
;; 0 = free cell, 1 = obstacle.
;;
;; The grid is a list of lists, where each element is 0 (walkable)
;; or 1 (blocked). This representation works with functional programming
;; because the grid never changes - we just read from it.
;;
(define sample-grid
  '((0 0 0 1 0)
    (0 1 0 1 0)
    (0 1 0 0 0)
    (0 0 0 1 0)))

(define sample-start '(0 0))
(define sample-goal '(2 4))

;;
;; Movement directions: up, down, left, right.
;;
;; Each is [row-delta col-delta]. The agent moves one step per direction.
;; We don't include diagonals because they require a different heuristic.
;;
(define directions
  '((-1 0) (1 0) (0 -1) (0 1)))

;;
;; ==================== POSITION VALIDATION ====================
;;
;; Three levels of checking:
;; 1. inside-grid?: Check if position is within bounds
;; 2. walkable?: Check if position is not an obstacle
;; 3. valid-position?: Both must be true
;;
;; Why separate them?
;; Makes debugging easier - we know which condition failed.
;; Also keeps each function focused on one check.
;;

;;
;; Check if a position is within grid boundaries.
;;
;; A position is inside if both row and column are valid indices.
;; This must be checked before reading the grid to avoid crashes.
;;
(define (inside-grid? grid position)
  (define row (first position))
  (define col (second position))
  (and (integer? row)
       (integer? col)
       (not (empty? grid))
       (>= row 0)
       (>= col 0)
       (< row (length grid))
       (< col (length (first grid)))))

;;
;; Check if a position is walkable (not an obstacle).
;;
;; Assumes position is valid (inside grid).
;; A cell has value 0 (free) or 1 (blocked).
;; We can only walk on 0.
;;
(define (walkable? grid position)
  (and (inside-grid? grid position)
       (= (list-ref (list-ref grid (first position)) (second position)) 0)))

;;
;; Check if a position is valid for pathfinding.
;;
;; A position is valid if it's inside the grid AND not blocked.
;; This is the ultimate check before adding to frontier.
;;
(define (valid-position? grid position)
  (and (inside-grid? grid position)
       (walkable? grid position)))

;;
;; ==================== MOVEMENT AND NEIGHBORS ====================
;;

;;
;; Apply a direction offset to a position to get a new position.
;;
;; Example: position (2,3) + direction (-1,0) = (1,3) [one step up]
;;
;; This is pure functional: creates a new position without changing input.
;;
(define (move-position position direction)
  (list (+ (first position) (first direction))
        (+ (second position) (second direction))))

;;
;; Get all valid neighboring cells from a position.
;;
;; Process:
;; 1. Apply each direction to create candidate positions
;; 2. Filter out invalid candidates (outside grid or obstacles)
;; 3. Return only valid neighbors
;;
;; This is an example of functional composition:
;; map: generate candidates
;; filter: remove invalid ones
;;
;; Why this approach?
;; Separates the "generate all moves" step from "check validity" step.
;; Makes the logic clear: transform, then filter.
;;
(define (neighbors grid position)
  (filter (lambda (candidate) (valid-position? grid candidate))
          (map (lambda (direction) (move-position position direction))
               directions)))

;;
;; ==================== HEURISTIC AND SCORING ====================
;;

;;
;; Manhattan distance: sum of absolute differences in rows and columns.
;;
;; This is the heuristic h(n) - an estimate of remaining distance to goal.
;;
;; Why Manhattan?
;; - Matches our movement model (only 4 directions, no diagonals)
;; - Never overestimates the actual shortest distance
;; - Fast to compute (just addition and subtraction)
;;
;; Example: From (0,0) to (3,4)
;; h = |0-3| + |0-4| = 3 + 4 = 7
;;
;; The heuristic guides A* toward the goal without guaranteeing optimality.
;; But for 4-direction movement, it works perfectly.
;;
(define (manhattan a b)
  (+ (abs (- (first a) (first b)))
     (abs (- (second a) (second b)))))

;;
;; Create a node for a position and calculate its A* scores.
;;
;; Inputs:
;;   position: where this node is on the grid
;;   g: cost from start (inherited from parent)
;;   goal: target position (to calculate h)
;;   parent: previous node in path (needed for reconstruction)
;;
;; We calculate h here because every node needs it to compute f.
;; f = g + h is what A* uses to pick the next node.
;;
;; Why immutable?
;; Creating a new node instead of modifying one.
;; The parent node stays unchanged. This is key to functional style.
;;
(define (make-node position g goal parent)
  (define h (manhattan position goal))
  (node position g h (+ g h) parent))

;;
;; Compare two nodes to determine which is better for A*.
;;
;; A node is "better" if:
;; 1. Its f score is lower (primary rule)
;; 2. If f scores tie, its h score is lower (tiebreaker)
;;
;; Why this tiebreaker?
;; When f is equal, prefer nodes closer to goal (lower h).
;; This often makes A* find the goal faster.
;;
;; Example:
;; Node A: g=5, h=3, f=8
;; Node B: g=4, h=4, f=8
;; Both have f=8, but B is closer to goal (h=4), so B is better.
;;
(define (lower-score? left right)
  (or (< (node-f left) (node-f right))
      (and (= (node-f left) (node-f right))
           (< (node-h left) (node-h right)))))

;;
;; ==================== FRONTIER MANAGEMENT ====================
;;
;; The frontier is the "waiting list" of cells to explore.
;; Nodes enter the frontier when discovered.
;; Nodes leave when selected as best node.
;;

;;
;; Find the best node in the frontier.
;;
;; Best means: lowest f score, used as tiebreaker by lower-score?.
;;
;; Implementation: scan entire frontier, keep node with best score.
;; This is O(n) per call, which is slower than priority queue,
;; but much simpler to understand and explain.
;;
;; For this project, simplicity is the goal.
;; The list-based frontier keeps the algorithm clear.
;;
(define (best-node frontier)
  (cond
    [(empty? frontier) #f]
    [else
     (foldl (lambda (candidate best)
              (if (lower-score? candidate best) candidate best))
            (first frontier)
            (rest frontier))]))

;;
;; Remove a specific node from the frontier.
;;
;; Once a node is selected (best-node), it leaves frontier
;; and enters visited. This function removes it.
;;
;; We use equal? to compare nodes, which checks all fields.
;; This is safe because nodes include position and parent info.
;;
(define (remove-node target frontier)
  (filter (lambda (candidate) (not (equal? candidate target))) frontier))

;;
;; Check if a list of nodes contains a certain position.
;;
;; Searches through nodes and compares their positions.
;; Returns #t (true) if found, #f (false) if not.
;;
;; Used to:
;; - Check if position already visited (can't re-add to frontier)
;; - Check if position already in frontier (might improve it)
;;
(define (contains-position? nodes position)
  (ormap (lambda (current) (equal? (node-position current) position)) nodes))

;;
;; Find a node in a list by its position.
;;
;; Returns the node if found, #f if not found.
;;
;; Why needed?
;; When we discover a position again, we might find a cheaper path to it.
;; We need to locate the old node to compare costs (old g vs new g).
;;
(define (find-position nodes position)
  (cond
    [(empty? nodes) #f]
    [(equal? (node-position (first nodes)) position) (first nodes)]
    [else (find-position (rest nodes) position)]))

;;
;; Replace a node in a list with an improved version.
;;
;; The new node has the same position but better (lower) g score.
;;
;; Process:
;; - Go through each node in the list
;; - If its position matches the replacement, use the replacement
;; - Otherwise, keep the original
;;
;; Returns a new list (functional - doesn't modify original).
;;
(define (replace-position nodes replacement)
  (map (lambda (current)
         (if (equal? (node-position current) (node-position replacement))
             replacement
             current))
       nodes))

;;
;; Add a new node to frontier, or improve an existing entry.
;;
;; When we discover a position:
;; 1. Check if it's already in frontier
;; 2. If not: add it (cons to front)
;; 3. If yes: compare g costs
;; 4. If new path is cheaper: replace it
;; 5. If new path is more expensive: ignore it
;;
;; This is important for A* correctness.
;; Always keep the shortest known path to each position.
;;
;; Functional approach: return updated frontier.
;; Original frontier unchanged (new list returned).
;;
(define (add-or-improve frontier candidate)
  (define existing (find-position frontier (node-position candidate)))
  (cond
    [(not existing) (cons candidate frontier)]
    [(< (node-g candidate) (node-g existing))
     (replace-position frontier candidate)]
    [else frontier]))

;;
;; ==================== FRONTIER EXPANSION ====================
;;

;;
;; Generate new frontier entries from neighbors of current node.
;;
;; When we process a node, we look at its neighbors.
;; For each neighbor not already visited:
;; - Create a new node with parent = current node
;; - Cost g = parent's g + 1 (each step costs 1)
;; - Calculate h using Manhattan distance
;; - Add to frontier (or improve if already there)
;;
;; This is the "exploration" step of A*.
;;
;; Functional approach: takes frontier, returns updated frontier.
;; Original frontier is not modified.
;;
(define (expand-frontier grid current frontier visited goal)
  (foldl
   (lambda (position updated-frontier)
     ;; Skip neighbors that are already visited
     ;; (already processed, no need to re-add)
     (if (contains-position? visited position)
         updated-frontier
         ;; For each unvisited neighbor:
         ;; Create a new node and add it to frontier
         ;; g = current node's g + 1 (one more step)
         ;; parent = current node (for path reconstruction)
         (add-or-improve
          updated-frontier
          (make-node position
                     (+ (node-g current) 1)
                     goal
                     current))))
   frontier
   (neighbors grid (node-position current))))

;;
;; ==================== PATH RECONSTRUCTION ====================
;;

;;
;; Rebuild the final path by following parent links backward from goal.
;;
;; When we reach the goal, each node has a parent.
;; Following parent links backward:
;; goal -> parent -> grandparent -> ... -> start (start has no parent)
;;
;; Process:
;; 1. Start at goal node
;; 2. Add position to path
;; 3. Move to parent and repeat
;; 4. Stop when no more parents (reached start)
;; 5. Reverse to get start -> goal order
;;
;; Why built backward?
;; Following parent links is natural (each node knows its parent).
;; We cons (prepend) to build path efficiently.
;; Then reverse to get correct order.
;;
;; This is an inner function (walk) for clarity.
;; walk: collects positions as it walks the parent chain.
;;
(define (reconstruct-path current-node)
  (define (walk node-so-far path-so-far)
    (if (not node-so-far)
        ;; No more parents: we reached the start
        path-so-far
        ;; Add this node's position and continue
        (walk (node-parent node-so-far)
              (cons (node-position node-so-far) path-so-far))))
  (walk current-node '()))

;;
;; Convert a list of nodes to a list of positions.
;;
;; Why?
;; React visualizer only needs positions for display.
;; A* scores (g, h, f) are not needed in output.
;; This extracts just the coordinates.
;;
(define (positions-of nodes)
  (map node-position nodes))

;;
;; ==================== MAIN A* SEARCH ====================
;;

;;
;; Recursive A* search - the core algorithm.
;;
;; Inputs:
;;   grid: board to search
;;   frontier: nodes waiting to be explored
;;   visited: nodes already processed
;;   goal: target position
;;
;; Output: hash with 'success, 'path, 'visited keys
;;
;; Algorithm (each recursive call is one step):
;; 1. If frontier empty: no path exists, return failure
;; 2. Pick best frontier node (lowest f)
;; 3. If it's the goal: path found, reconstruct and return
;; 4. Otherwise: generate neighbors, add to frontier, recurse
;;
;; Why recursive?
;; Each A* step is identical: pick best, process, continue.
;; Recursion naturally expresses this repetition.
;; Base case: frontier empty (no more nodes to explore).
;;
;; Why return a hash?
;; Need to return multiple values: success flag, path, visited.
;; Hash makes this clean (key-value pairs).
;; Receiver can extract what it needs.
;;
(define (a-star-search grid frontier visited goal)
  (cond
    ;; CASE 1: Frontier empty
    ;; We explored everywhere but never found the goal.
    ;; This means no path exists.
    [(empty? frontier)
     (hash 'success #f
           'visited (reverse (positions-of visited))
           'path '())]

    ;; CASE 2: Frontier not empty
    ;; Continue searching: pick best node, process it, recurse.
    [else
     (define current (best-node frontier))
     (define next-frontier (remove-node current frontier))
     (define next-visited (cons current visited))

     ;; Did we reach the goal?
     (if (equal? (node-position current) goal)
         ;; YES: goal found
         ;; Reconstruct path by following parent links
         (hash 'success #t
               'visited (reverse (positions-of next-visited))
               'path (reconstruct-path current))

         ;; NO: goal not yet found
         ;; Expand from current node and recurse
         ;; expand-frontier generates neighbors and updates frontier
         ;; Recursive call with updated frontier and visited
         (a-star-search grid
                        (expand-frontier grid current next-frontier next-visited goal)
                        next-visited
                        goal))]))

;;
;; ==================== PUBLIC ENTRY POINT ====================
;;

;;
;; Find the shortest path from start to goal.
;;
;; This is the main function to call from outside.
;; It validates input, initializes the search, and returns results.
;;
;; Input:
;;   grid: the board (list of lists, 0=free 1=obstacle)
;;   start: starting position [row col]
;;   goal: goal position [row col]
;;
;; Output: hash with keys:
;;   'success: #t if path found, #f otherwise
;;   'path: list of [row col] from start to goal (empty if no path)
;;   'visited: list of all explored positions (for visualization)
;;   'error: (optional) error message if validation fails
;;
;; Validation:
;; 1. Check start is valid (in grid, not obstacle)
;; 2. Check goal is valid (in grid, not obstacle)
;; 3. If both valid: initialize and search
;; 4. If either invalid: return error without searching
;;
;; Why validate first?
;; Prevents wasting computation on impossible inputs.
;; Makes error messages clear (know which input failed).
;;
(define (a-star grid start goal)
  (cond
    ;; Start position is invalid
    [(not (valid-position? grid start))
     (hash 'success #f
           'visited '()
           'path '()
           'error "Invalid start position")]

    ;; Goal position is invalid
    [(not (valid-position? grid goal))
     (hash 'success #f
           'visited '()
           'path '()
           'error "Invalid goal position")]

    ;; Both valid - run the search
    [else
     (a-star-search grid
                    ;; Initial frontier: just the start node
                    ;; g=0 (no cost yet, just starting)
                    ;; parent=#f (no previous node)
                    (list (make-node start 0 goal #f))
                    ;; Initial visited: empty (nothing processed yet)
                    '()
                    goal)]))
