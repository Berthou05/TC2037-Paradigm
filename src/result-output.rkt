#lang racket

;;
;; RESULT OUTPUT AND GRID GENERATION
;;
;; This module bridges the A* algorithm and the React visualizer.
;; It can generate random grids and run A* on them.
;;

(require json
         "../astar-implementation/astar.rkt"
         "grid-gen.rkt")

(provide result->jsexpr
         write-result-json
         generate-and-solve
         write-generated-grid)

;;
;; Builds the JSON-friendly value consumed by the visualizer.
;;
;; The payload includes the original grid, start, goal, visited cells and
;; final path so React can draw the full search result.
;;
(define (result->jsexpr grid start goal result)
  (define base
    (hash 'success (hash-ref result 'success)
          'grid grid
          'start start
          'goal goal
          'visited (hash-ref result 'visited)
          'path (hash-ref result 'path)))
  (if (hash-has-key? result 'error)
      (hash-set base 'error (hash-ref result 'error))
      base))

;;
;; Runs A* and writes its result to a JSON file.
;;
;; Parameters:
;;   path: file path where JSON will be written
;;   grid: the grid to search (optional, defaults to sample)
;;   start: start position (optional)
;;   goal: goal position (optional)
;;
(define (write-result-json path [grid sample-grid] [start sample-start] [goal sample-goal])
  (define result (a-star grid start goal))
  (call-with-output-file path
    (lambda (out)
      (write-json (result->jsexpr grid start goal result) out))
    #:exists 'replace)
  result)

;;
;; Generate a random grid and solve it.
;;
;; Parameters:
;;   rows: grid height
;;   cols: grid width
;;   density: obstacle density (0.0 to 1.0)
;;
;; Returns: result hash with path, visited, grid info
;;
(define (generate-and-solve rows cols density)
  (define spec (generate-grid-spec rows cols density))
  (define grid (hash-ref spec 'grid))
  (define start (hash-ref spec 'start))
  (define goal (hash-ref spec 'goal))
  (define result (a-star grid start goal))

  ;; Combine grid spec with result
  (hash-set result 'grid grid))

;;
;; Generate a random grid and write complete solution to JSON.
;;
;; Parameters:
;;   output-path: file path where JSON will be written
;;   rows: grid height
;;   cols: grid width
;;   density: obstacle density (0.0 to 1.0)
;;
;; This is called by the visualizer when user selects grid parameters.
;;
(define (write-generated-grid output-path rows cols density)
  (define spec (generate-grid-spec rows cols density))
  (define grid (hash-ref spec 'grid))
  (define start (hash-ref spec 'start))
  (define goal (hash-ref spec 'goal))
  (define result (a-star grid start goal))

  (call-with-output-file output-path
    (lambda (out)
      (write-json (result->jsexpr grid start goal result) out))
    #:exists 'replace)

  result)

;; Default: write sample grid result
(module+ main
  (write-result-json "output/result.json")
  (displayln "Wrote output/result.json"))
