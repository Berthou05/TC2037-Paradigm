#lang racket

;;
;; Helper test runner used by tests/bfs_compare.py.
;; It prints fixed and generated A* case results as JSON so Python can
;; validate them against the optimal path length.
;; AI assistance was used to optimize and organize this testing helper.
;;

(require json
         "../astar-implementation/astar.rkt"
         "../src/grid-gen.rkt")

(define generated-configs
  (list
   (list 101 12 12 0.15 "solvable")
   (list 102 12 12 0.25 "solvable")
   (list 103 15 15 0.20 "solvable")
   (list 104 15 15 0.35 "solvable")
   (list 105 20 20 0.20 "solvable")
   (list 106 20 20 0.35 "solvable")
   (list 107 25 25 0.25 "solvable")
   (list 108 25 25 0.40 "solvable")
   (list 109 15 15 0.25 "random")
   (list 110 20 20 0.30 "random")
   (list 111 25 25 0.35 "random")
   (list 112 18 18 0.30 "blocked")))

(define (generated-case config)
  (define seed (first config))
  (define rows (second config))
  (define cols (third config))
  (define density (fourth config))
  (define mode (fifth config))
  (random-seed seed)
  (define spec (generate-grid-spec rows cols density mode))
  (hash 'name (format "generated ~ax~a density ~a ~a seed ~a"
                      rows
                      cols
                      density
                      mode
                      seed)
        'grid (hash-ref spec 'grid)
        'start (hash-ref spec 'start)
        'goal (hash-ref spec 'goal)))

(define fixed-cases
  (list
   (hash 'name "fixed simple path"
         'grid sample-grid
         'start sample-start
         'goal sample-goal)
   (hash 'name "fixed no solution"
         'grid '((0 0 0 0 0)
                 (0 1 1 1 0)
                 (0 1 0 1 0)
                 (0 1 1 1 0)
                 (0 0 0 0 0))
         'start '(0 0)
         'goal '(2 2))
   (hash 'name "fixed start equals goal"
         'grid sample-grid
         'start '(0 0)
         'goal '(0 0))
   (hash 'name "fixed invalid start"
         'grid sample-grid
         'start '(0 3)
         'goal sample-goal)
   (hash 'name "fixed invalid goal"
         'grid sample-grid
         'start sample-start
         'goal '(10 10))))

(define cases
  (append fixed-cases
          (map generated-case generated-configs)))

(define (case->result current-case)
  (define grid (hash-ref current-case 'grid))
  (define start (hash-ref current-case 'start))
  (define goal (hash-ref current-case 'goal))
  (define result (a-star grid start goal))

  (hash 'name (hash-ref current-case 'name)
        'grid grid
        'start start
        'goal goal
        'success (result-success result)
        'path (result-path result)
        'error (result-error result)))

(write-json (map case->result cases))
(newline)
