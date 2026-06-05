#lang racket

;;
;; Base tests for the Racket A* implementation.
;; A separate Python script validates fixed and generated cases against the
;; optimal path length.
;; This file is used to verify behavior, not to implement the algorithm.
;; AI assistance was used to optimize and organize the testing workflow.
;;

(require rackunit
         racket/runtime-path
         "../astar-implementation/astar.rkt")

(define-runtime-path bfs-script "bfs_compare.py")

(define (all-adjacent? path)
  (cond
    [(or (empty? path) (empty? (rest path))) #t]
    [else
     (and (= (manhattan (first path) (second path)) 1)
          (all-adjacent? (rest path)))]))

(define (valid-path? grid path start goal)
  (and (not (empty? path))
       (equal? (first path) start)
       (equal? (last path) goal)
       (andmap (lambda (position) (valid-position? grid position)) path)
       (all-adjacent? path)))

(test-case "Base case: simple path"
  (define result (a-star sample-grid sample-start sample-goal))
  (define path (result-path result))

  (check-true (result-success result))
  (check-equal? (first (result-visited result)) sample-start)
  (check-true (valid-path? sample-grid path sample-start sample-goal)))

(test-case "Base case: no solution"
  (define grid
    '((0 0 0 0 0)
      (0 1 1 1 0)
      (0 1 0 1 0)
      (0 1 1 1 0)
      (0 0 0 0 0)))

  (define result (a-star grid '(0 0) '(2 2)))

  (check-false (result-success result))
  (check-equal? (first (result-visited result)) '(0 0))
  (check-equal? (result-path result) '()))

(test-case "Base case: start equals goal"
  (define result (a-star sample-grid '(0 0) '(0 0)))

  (check-true (result-success result))
  (check-equal? (result-visited result) '((0 0)))
  (check-equal? (result-path result) '((0 0))))

(test-case "Base case: invalid start"
  (define result (a-star sample-grid '(0 3) sample-goal))

  (check-false (result-success result))
  (check-equal? (result-visited result) '())
  (check-equal? (result-error result) "Invalid start position"))

(test-case "Base case: invalid goal"
  (define result (a-star sample-grid sample-start '(10 10)))

  (check-false (result-success result))
  (check-equal? (result-visited result) '())
  (check-equal? (result-error result) "Invalid goal position"))

(test-case "Optimal-path validation"
  (define python
    (or (find-executable-path "python")
        (find-executable-path "py")))
  (define racket-exe (find-system-path 'exec-file))
  (check-not-false python)
  (check-true (system* python bfs-script racket-exe)))
