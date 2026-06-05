#lang racket

;;
;; A* PATHFINDING - FUNCTIONAL IMPLEMENTATION
;;
;; Finds the shortest path between two cells in a grid using the A* algorithm.
;; Movement is restricted to four directions: up, down, left, right.
;; Obstacles are represented as 1; free cells as 0.
;;

(provide node
         node-position node-g node-h node-f node-parent
         result-success result-visited result-path result-error
         sample-grid sample-start sample-goal
         directions
         inside-grid? walkable? valid-position?
         neighbors
         manhattan
         make-node
         priority-queue-empty?
         priority-queue-insert
         priority-queue-min
         priority-queue-remove-min
         best-node
         remove-best-node
         reconstruct-path
         a-star)

;; ============================================================
;; POSITIONS
;;
;; A position is a two-element list: (row col).
;; ============================================================

(define (position-row pos) (first pos))
(define (position-col pos) (first (rest pos)))

;; True when two positions refer to the same cell.
(define (same-position? a b)
  (and (= (position-row a) (position-row b))
       (= (position-col a) (position-col b))))

;; ============================================================
;; NODES
;;
;; A node records one cell visited during the search.
;; It stores: position, cost so far (g), heuristic estimate (h),
;; total score (f = g + h), and a reference to the parent node.
;; ============================================================

(define (node position g h f parent) (list position g h f parent))

(define (node-position n) (first n))
(define (node-g n)        (first (rest n)))
(define (node-h n)        (first (rest (rest n))))
(define (node-f n)        (first (rest (rest (rest n)))))
(define (node-parent n)   (first (rest (rest (rest (rest n))))))

;; ============================================================
;; RESULTS
;;
;; The search returns a result: (success visited path error).
;;   success - true if a path was found
;;   visited - all cells explored, in order
;;   path    - the shortest path from start to goal
;;   error   - an error message string, or false
;; ============================================================

(define (result success visited path error) (list success visited path error))

(define (result-success r) (first r))
(define (result-visited r) (first (rest r)))
(define (result-path r)    (first (rest (rest r))))
(define (result-error r)   (first (rest (rest (rest r)))))

;; ============================================================
;; SAMPLE DATA
;; ============================================================

;; 0 = free, 1 = obstacle
(define sample-grid
  '((0 0 0 1 0)
    (0 1 0 1 0)
    (0 1 0 0 0)
    (0 0 0 1 0)))

(define sample-start '(0 0))
(define sample-goal  '(2 4))

;; The four cardinal directions as (row-delta col-delta).
(define directions '((-1 0) (1 0) (0 -1) (0 1)))

;; ============================================================
;; GRID ACCESS
;; ============================================================

;; Return the nth element of a list, or false when the index is out of bounds.
(define (nth-element-or-false lst n)
  (cond
    [(or (< n 0) (empty? lst)) false]
    [(= n 0) (first lst)]
    [else (nth-element-or-false (rest lst) (- n 1))]))

;; Return the cell value at a position, or false when the position is outside the grid.
(define (grid-cell-at grid pos)
  (define row (nth-element-or-false grid (position-row pos)))
  (if row
      (nth-element-or-false row (position-col pos))
      false))

;; True when the position exists inside the grid boundaries.
(define (inside-grid? grid pos)
  (not (equal? (grid-cell-at grid pos) false)))

;; True when the cell holds no obstacle.
(define (walkable? grid pos)
  (equal? (grid-cell-at grid pos) 0))

;; A position is valid only when it is inside the grid and walkable.
(define (valid-position? grid pos)
  (and (inside-grid? grid pos) (walkable? grid pos)))

;; ============================================================
;; NEIGHBORS
;;
;; map produces one candidate position per direction.
;; filter keeps only the positions that are inside the grid and walkable.
;; ============================================================

;; Apply a direction step to a position to obtain the adjacent cell.
(define (step-in-direction pos dir)
  (list (+ (position-row pos) (position-row dir))
        (+ (position-col pos) (position-col dir))))

;; Return all valid neighbors reachable from pos in one step.
(define (neighbors grid pos)
  (filter (lambda (candidate) (valid-position? grid candidate))
          (map (lambda (dir) (step-in-direction pos dir))
               directions)))

;; ============================================================
;; HEURISTIC
;;
;; Manhattan distance counts how many horizontal and vertical
;; steps separate two cells, ignoring obstacles.
;; ============================================================

;; Absolute difference between two numbers.
(define (absolute-difference a b) (if (< a b) (- b a) (- a b)))

;; Manhattan distance between two grid positions.
(define (manhattan a b)
  (+ (absolute-difference (position-row a) (position-row b))
     (absolute-difference (position-col a) (position-col b))))

;; Build a scored node from a position, its cost so far, the goal, and its parent.
(define (make-node pos cost-so-far goal parent)
  (define estimated-remaining (manhattan pos goal))
  (node pos cost-so-far estimated-remaining
        (+ cost-so-far estimated-remaining)
        parent))

;; ============================================================
;; PRIORITY QUEUE (leftist heap)
;;
;; Always removes the node with the lowest total score (f).
;; Ties are broken by the lower heuristic estimate (h).
;;
;; Each heap entry: (rank search-node left-subtree right-subtree)
;; ============================================================

(define (heap-entry rank search-node left-subtree right-subtree)
  (list rank search-node left-subtree right-subtree))

(define (heap-rank entry)          (if (empty? entry) 0 (first entry)))
(define (heap-search-node entry)   (first (rest entry)))
(define (heap-left-subtree entry)  (first (rest (rest entry))))
(define (heap-right-subtree entry) (first (rest (rest (rest entry)))))

;; True when search-node-a has a lower (better) score than search-node-b.
(define (lower-total-score? search-node-a search-node-b)
  (or (< (node-f search-node-a) (node-f search-node-b))
      (and (= (node-f search-node-a) (node-f search-node-b))
           (< (node-h search-node-a) (node-h search-node-b)))))

;; Merge two heaps, keeping the lowest-scored node at the root.
(define (merge-heaps heap-a heap-b)
  (cond
    [(empty? heap-a) heap-b]
    [(empty? heap-b) heap-a]
    [(lower-total-score? (heap-search-node heap-b) (heap-search-node heap-a))
     (merge-heaps heap-b heap-a)]
    [else
     (define merged-right (merge-heaps (heap-right-subtree heap-a) heap-b))
     (define left         (heap-left-subtree heap-a))
     (if (< (heap-rank left) (heap-rank merged-right))
         (heap-entry (+ (heap-rank left) 1)
                     (heap-search-node heap-a) merged-right left)
         (heap-entry (+ (heap-rank merged-right) 1)
                     (heap-search-node heap-a) left merged-right))]))

(define (priority-queue-empty? queue) (empty? queue))

;; Add a search node to the priority queue.
(define (priority-queue-insert search-node queue)
  (merge-heaps (heap-entry 1 search-node empty empty) queue))

;; Return the search node with the lowest score, without removing it.
(define (priority-queue-min queue)
  (if (empty? queue) false (heap-search-node queue)))

;; Remove the lowest-scored node and return the remaining queue.
(define (priority-queue-remove-min queue)
  (if (empty? queue)
      empty
      (merge-heaps (heap-left-subtree queue) (heap-right-subtree queue))))

;; Aliases matching the public interface expected by tests.
(define (best-node frontier)        (priority-queue-min frontier))
(define (remove-best-node frontier) (priority-queue-remove-min frontier))

;; ============================================================
;; PATH RECONSTRUCTION
;;
;; Each node points to its parent. Walking parent links from the
;; goal back to the start builds the path; the accumulator keeps
;; it in start-to-goal order.
;; ============================================================

(define (reconstruct-path goal-node)
  (define (follow-parent-links current-node path-so-far)
    (if current-node
        (follow-parent-links (node-parent current-node)
                             (cons (node-position current-node) path-so-far))
        path-so-far))
  (follow-parent-links goal-node empty))

;; Extract only the positions from a list of search nodes.
;;
;; map applies node-position to every node in the list.
(define (extract-positions-from-nodes node-list)
  (map (lambda (n) (node-position n)) node-list))

;; ============================================================
;; FRONTIER EXPANSION
;;
;; For each unvisited neighbor of the current node, create a new
;; search node and add it to the frontier.
;; ============================================================

;; True when the visited list already contains a node at this position.
;;
;; findf walks the list and returns the first node whose position matches,
;; or false when none is found.
(define (position-already-visited? visited-nodes pos)
  (if (findf (lambda (n) (same-position? (node-position n) pos)) visited-nodes)
      true
      false))

;; Insert search nodes for all unvisited neighbor positions into the frontier.
(define (enqueue-unvisited-neighbors neighbor-positions current-node frontier visited-nodes goal)
  (cond
    [(empty? neighbor-positions) frontier]
    [(position-already-visited? visited-nodes (first neighbor-positions))
     (enqueue-unvisited-neighbors
      (rest neighbor-positions) current-node frontier visited-nodes goal)]
    [else
     (enqueue-unvisited-neighbors
      (rest neighbor-positions)
      current-node
      (priority-queue-insert
       (make-node (first neighbor-positions)
                  (+ (node-g current-node) 1)
                  goal
                  current-node)
       frontier)
      visited-nodes
      goal)]))

;; ============================================================
;; A* SEARCH LOOP
;;
;; Each recursive call processes one node from the frontier:
;;   1. Empty frontier -> no path exists.
;;   2. Already visited -> skip and continue.
;;   3. Goal reached -> reconstruct and return the path.
;;   4. Otherwise -> expand neighbors and continue.
;; ============================================================

(define (search-from-frontier grid frontier visited-nodes goal)
  (cond
    [(priority-queue-empty? frontier)
     (result false (extract-positions-from-nodes visited-nodes) empty false)]
    [else
     (define current-node             (best-node frontier))
     (define frontier-without-current (remove-best-node frontier))
     (define visited-with-current     (cons current-node visited-nodes))
     (cond
       [(position-already-visited? visited-nodes (node-position current-node))
        (search-from-frontier grid frontier-without-current visited-nodes goal)]
       [(same-position? (node-position current-node) goal)
        (result true
                (extract-positions-from-nodes visited-with-current)
                (reconstruct-path current-node)
                false)]
       [else
        (search-from-frontier
         grid
         (enqueue-unvisited-neighbors (neighbors grid (node-position current-node))
                                      current-node
                                      frontier-without-current
                                      visited-with-current
                                      goal)
         visited-with-current
         goal)])]))


;; =================== End of A* implementation ===============


;; ============================================================
;; PUBLIC ENTRY POINT
;;
;; This is used by the tests. It validates the input and 
;; starts the search. It is not part of the core algorithm.
;; ============================================================

;; Find the shortest path from start to goal in the given grid.
;; Returns a result record (see result-* accessors above).
(define (a-star grid start goal)
  (cond
    [(not (valid-position? grid start))
     (result false empty empty "Invalid start position")]
    [(not (valid-position? grid goal))
     (result false empty empty "Invalid goal position")]
    [else
     (search-from-frontier grid
                           (priority-queue-insert (make-node start 0 goal false) empty)
                           empty
                           goal)]))
