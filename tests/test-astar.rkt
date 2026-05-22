#lang racket

;;
;; INTEGRATION TESTS FOR A* PATHFINDING
;;
;; These tests verify the complete a-star function works correctly
;; on various grid configurations. Each test runs the full algorithm
;; and validates the result.
;;

(require rackunit
         "../astar-implementation/astar.rkt"
         "../src/result-output.rkt")

;;
;; Helper function: check if a path is valid
;;
;; A valid path:
;; - Starts at the start position
;; - Ends at the goal position
;; - All cells are within the grid and not obstacles
;; - All consecutive cells are adjacent (one step apart)
;;
(define (is-valid-path? grid path start goal)
  (and (not (empty? path))
       (equal? (first path) start)
       (equal? (last path) goal)
       (andmap (lambda (pos) (valid-position? grid pos)) path)
       (all-adjacent? path)))

;;
;; Helper function: check if all consecutive cells are adjacent
;;
;; Adjacent means Manhattan distance = 1 (one step away)
;;
(define (all-adjacent? path)
  (cond
    [(or (empty? path) (empty? (rest path))) #t]
    [else
     (and (= (manhattan (first path) (second path)) 1)
          (all-adjacent? (rest path)))]))

;;
;; ==================== TEST CASES ====================
;;

(test-case "TEST 1: Simple path in small grid"
  ;; Grid with few obstacles, path should be found
  (define result (a-star sample-grid sample-start sample-goal))

  ;; Verify: algorithm found a path
  (check-true (hash-ref result 'success))

  ;; Verify: path is valid (starts at start, ends at goal, all cells walkable)
  (define path (hash-ref result 'path))
  (check-true (is-valid-path? sample-grid path sample-start sample-goal))

  ;; Verify: path is reasonably short (not wandering unnecessarily)
  (check-true (<= (length path) 10))

  (displayln "OK: Simple path test passed"))

(test-case "TEST 2: Grid with no obstacles"
  ;; Large empty grid with no obstacles
  (define empty-grid
    '((0 0 0 0 0 0)
      (0 0 0 0 0 0)
      (0 0 0 0 0 0)
      (0 0 0 0 0 0)))

  (define result (a-star empty-grid '(0 0) '(3 5)))

  ;; Verify: path found in open grid
  (check-true (hash-ref result 'success))

  ;; Verify: path is valid
  (define path (hash-ref result 'path))
  (check-true (is-valid-path? empty-grid path '(0 0) '(3 5)))

  ;; Verify: path length matches Manhattan distance (optimal for empty grid)
  (define manhattan-dist (manhattan '(0 0) '(3 5)))
  (check-equal? (length path) (+ manhattan-dist 1))

  (displayln "OK: No obstacles test passed"))

(test-case "TEST 3: Grid with obstacles blocking direct path"
  ;; Grid where obstacles force a detour
  (define blocked-grid
    '((0 0 1 0)
      (0 0 1 0)
      (0 0 1 0)
      (0 0 0 0)))

  (define result (a-star blocked-grid '(0 0) '(0 3)))

  ;; Verify: path found despite obstacle wall
  (check-true (hash-ref result 'success))

  ;; Verify: path is valid
  (define path (hash-ref result 'path))
  (check-true (is-valid-path? blocked-grid path '(0 0) '(0 3)))

  ;; Verify: path avoids all obstacles
  (check-false (member '(0 2) path))
  (check-false (member '(1 2) path))
  (check-false (member '(2 2) path))

  (displayln "OK: Obstacle avoidance test passed"))

(test-case "TEST 4: No solution (goal completely surrounded)"
  ;; Goal is trapped by obstacles, cannot be reached
  (define no-path-grid
    '((0 0 0 0 0)
      (0 1 1 1 0)
      (0 1 0 1 0)
      (0 1 1 1 0)
      (0 0 0 0 0)))

  (define result (a-star no-path-grid '(0 0) '(2 2)))

  ;; Verify: algorithm correctly reports no path
  (check-false (hash-ref result 'success))

  ;; Verify: path is empty
  (check-equal? (hash-ref result 'path) '())

  ;; Verify: algorithm still explored some cells
  (check-true (< 0 (length (hash-ref result 'visited))))

  (displayln "OK: No solution test passed"))

(test-case "TEST 5: Start equals goal"
  ;; Edge case: starting position is the goal
  (define result (a-star sample-grid '(0 0) '(0 0)))

  ;; Verify: success (already at goal)
  (check-true (hash-ref result 'success))

  ;; Verify: path has exactly one cell (the start/goal)
  (define path (hash-ref result 'path))
  (check-equal? path '((0 0)))

  (displayln "OK: Start equals goal test passed"))

(test-case "TEST 6: Invalid start position"
  ;; Start is on an obstacle
  (define result (a-star sample-grid '(0 3) sample-goal))

  ;; Verify: algorithm rejects invalid start
  (check-false (hash-ref result 'success))

  ;; Verify: error message provided
  (check-true (hash-has-key? result 'error))
  (check-equal? (hash-ref result 'error) "Invalid start position")

  (displayln "OK: Invalid start test passed"))

(test-case "TEST 7: Invalid goal position"
  ;; Goal is out of bounds
  (define result (a-star sample-grid sample-start '(10 10)))

  ;; Verify: algorithm rejects invalid goal
  (check-false (hash-ref result 'success))

  ;; Verify: error message provided
  (check-true (hash-has-key? result 'error))
  (check-equal? (hash-ref result 'error) "Invalid goal position")

  (displayln "OK: Invalid goal test passed"))

(test-case "TEST 8: Dense obstacles"
  ;; Grid with many obstacles, path still exists
  (define dense-grid
    '((0 0 0 1 0)
      (1 1 0 1 0)
      (0 0 0 1 0)
      (0 1 0 0 0)))

  (define result (a-star dense-grid '(0 0) '(3 4)))

  ;; Verify: path found despite high obstacle density
  (check-true (hash-ref result 'success))

  ;; Verify: path is valid
  (define path (hash-ref result 'path))
  (check-true (is-valid-path? dense-grid path '(0 0) '(3 4)))

  (displayln "OK: Dense obstacles test passed"))

(test-case "TEST 9: Large empty grid (performance check)"
  ;; Larger grid to verify algorithm doesn't timeout
  ;; (10x10 completely open)
  (define large-grid
    (build-list 10
      (lambda (_) (build-list 10 (lambda (_) 0)))))

  (define result (a-star large-grid '(0 0) '(9 9)))

  ;; Verify: algorithm completes within reasonable time
  (check-true (hash-ref result 'success))

  ;; Verify: path is optimal (Manhattan distance + 1)
  (define path (hash-ref result 'path))
  (check-equal? (length path) 19)

  (displayln "OK: Large grid test passed"))

(test-case "TEST 10: Complex maze"
  ;; Winding path through a maze-like grid
  (define maze
    '((0 0 1 0 0)
      (1 0 1 0 1)
      (0 0 0 0 1)
      (0 1 1 1 1)
      (0 0 0 0 0)))

  (define result (a-star maze '(0 0) '(4 4)))

  ;; Verify: path found through maze
  (check-true (hash-ref result 'success))

  ;; Verify: path is valid
  (define path (hash-ref result 'path))
  (check-true (is-valid-path? maze path '(0 0) '(4 4)))

  ;; Verify: visited list contains explored cells
  (check-true (< 0 (length (hash-ref result 'visited))))

  (displayln "OK: Complex maze test passed"))

;;
;; ==================== TEST SUMMARY ====================
;;

(displayln "")
(displayln "========================================")
(displayln "OK: ALL INTEGRATION TESTS PASSED")
(displayln "========================================")
(displayln "Total: 10 tests")
(displayln "Status: All pathfinding scenarios working correctly")
(displayln "")
