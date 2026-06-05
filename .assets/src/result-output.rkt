#lang racket

;;
;; Helper module that converts A* results into JSON for the visualizer.
;; It is not part of the core algorithm.
;; This file exists so the React/Node visualizer can read Racket results.
;;

(require json
         "../../astar-implementation/astar.rkt"
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
    (hash 'success (result-success result)
          'grid grid
          'start start
          'goal goal
          'visited (result-visited result)
          'path (result-path result)))
  (if (result-error result)
      (hash-set base 'error (result-error result))
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
;; Returns: JSON-friendly hash with path, visited, grid info
;;
(define (generate-and-solve rows cols density)
  (define spec (generate-grid-spec rows cols density))
  (define grid (hash-ref spec 'grid))
  (define start (hash-ref spec 'start))
  (define goal (hash-ref spec 'goal))
  (define result (a-star grid start goal))

  ;; Convert the simple A* result into the same JSON-friendly shape.
  (result->jsexpr grid start goal result))

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
  (write-result-json ".assets/output/result.json")
  (displayln "Wrote .assets/output/result.json"))
