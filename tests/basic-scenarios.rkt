#lang racket

;;
;; Basic scenario tests for the A* implementation.
;;

(require rackunit
         "../astar-implementation/astar.rkt")

(define no-solution-grid
  '((0 0 0 0 0)
    (0 1 1 1 0)
    (0 1 0 1 0)
    (0 1 1 1 0)
    (0 0 0 0 0)))

;; Shorthand: run a-star and check success, path, and error in one call.
(define (check-astar name grid start goal expected-success expected-path expected-error)
  (test-case name
    (define r (a-star grid start goal))
    (check-equal? (result-success r) expected-success)
    (check-equal? (result-path    r) expected-path)
    (check-equal? (result-error   r) expected-error)))

(check-astar "simple path"
             sample-grid sample-start sample-goal
             true '((0 0) (0 1) (0 2) (1 2) (2 2) (2 3) (2 4)) false)

(check-astar "no solution"
             no-solution-grid '(0 0) '(2 2)
             false '() false)

(check-astar "start equals goal"
             sample-grid '(0 0) '(0 0)
             true '((0 0)) false)

(check-astar "invalid start"
             sample-grid '(0 3) sample-goal
             false '() "Invalid start position")

(check-astar "invalid goal"
             sample-grid sample-start '(10 10)
             false '() "Invalid goal position")