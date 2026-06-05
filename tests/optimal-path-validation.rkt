#lang racket

;;
;; Validates A* against the optimal path length.
;; BFS finds the shortest path in the same unweighted grid to use as ground truth.
;;

(require "../astar-implementation/astar.rkt"
         (file "../.assets/src/grid-gen.rkt"))

;; ============================================================
;; BFS - OPTIMAL PATH REFERENCE
;;
;; Returns the shortest path from start to goal as a list of
;; positions, or empty when no path exists.
;;
;; The frontier holds complete paths so the goal path is ready
;; the moment the goal position is dequeued.
;; ============================================================

(define (bfs grid start goal)
  (define (search queue visited)
    (cond
      [(empty? queue) empty]
      [(equal? (last (first queue)) goal) (first queue)]
      [else
       (define current-path  (first queue))
       (define current-pos   (last current-path))
       (define unvisited     (filter (lambda (pos) (not (member pos visited)))
                                     (neighbors grid current-pos)))
       (define extended-paths (map (lambda (pos) (append current-path (list pos)))
                                   unvisited))
       (search (append (rest queue) extended-paths)
               (append visited unvisited))]))
  (if (and (valid-position? grid start) (valid-position? grid goal))
      (search (list (list start)) (list start))
      empty))

;; ============================================================
;; TEST CASES
;; ============================================================

;; Hand-written cases covering known situations.
(define fixed-cases
  (list
   (list "simple path"     sample-grid sample-start sample-goal)
   (list "no solution"     '((0 0 0 0 0)
                             (0 1 1 1 0)
                             (0 1 0 1 0)
                             (0 1 1 1 0)
                             (0 0 0 0 0))  '(0 0) '(2 2))
   (list "start=goal"      sample-grid '(0 0) '(0 0))
   (list "invalid start"   sample-grid '(0 3) sample-goal)
   (list "invalid goal"    sample-grid sample-start '(10 10))))

;; Randomly generated grids with fixed seeds for reproducibility.
;; Each entry: (seed rows cols obstacle-density mode)
(define generated-configs
  '((101 12 12 0.15 "solvable")
    (102 12 12 0.25 "solvable")
    (103 15 15 0.20 "solvable")
    (104 15 15 0.35 "solvable")
    (105 20 20 0.20 "solvable")
    (106 20 20 0.35 "solvable")
    (107 25 25 0.25 "solvable")
    (108 25 25 0.40 "solvable")
    (109 15 15 0.25 "random")
    (110 20 20 0.30 "random")
    (111 25 25 0.35 "random")
    (112 18 18 0.30 "blocked")))

(define (config->case cfg)
  (random-seed (first cfg))
  (define spec (generate-grid-spec (second cfg) (third cfg) (fourth cfg) (fifth cfg)))
  (list "generated" (hash-ref spec 'grid) (hash-ref spec 'start) (hash-ref spec 'goal)))

(define all-cases (append fixed-cases (map config->case generated-configs)))

;; ============================================================
;; VALIDATION
;; ============================================================

(define (validate-case test-case)
  (define name      (first  test-case))
  (define grid      (second test-case))
  (define start     (third  test-case))
  (define goal      (fourth test-case))
  (define astar-result (a-star grid start goal))
  (define astar-path   (result-path astar-result))
  (define optimal-path (bfs grid start goal))
  (unless (equal? (result-success astar-result) (not (empty? optimal-path)))
    (error name "A* reachability does not match BFS"))
  (when (result-success astar-result)
    (unless (= (length astar-path) (length optimal-path))
      (error name "A* path length does not match BFS"))))

(for-each validate-case all-cases)

(displayln (format "All ~a tests passed" (length all-cases)))
