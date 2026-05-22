#lang racket

;;
;; SERVER-SIDE GRID GENERATION AND A* SOLVING
;;
;; Called by Node.js server with command-line arguments.
;; Generates a random grid and solves it with A*, outputting JSON.
;;
;; Usage: racket server-gen.rkt <rows> <cols> <density> [mode]
;; Example: racket server-gen.rkt 10 10 0.3 solvable
;;

(require json
         "../astar-implementation/astar.rkt"
         "grid-gen.rkt"
         "result-output.rkt")

;;
;; Parse command-line arguments and run the pathfinding algorithm.
;;
(define (main)
  (define args (current-command-line-arguments))

  ;; Validate arguments
  (when (< (vector-length args) 3)
    (write-json (hash 'success #f 'error "Missing arguments: rows cols density") (current-output-port))
    (newline)
    (exit 1))

  ;; Parse arguments
  (define rows (string->number (vector-ref args 0)))
  (define cols (string->number (vector-ref args 1)))
  (define density (string->number (vector-ref args 2)))
  (define mode
    (if (>= (vector-length args) 4)
        (vector-ref args 3)
        "random"))

  ;; Validate numbers
  (when (or (not rows) (not cols) (not density))
    (write-json (hash 'success #f 'error "Arguments must be numbers") (current-output-port))
    (newline)
    (exit 1))

  ;; Generate and solve
  (with-handlers
    ([exn:fail?
      (lambda (e)
        (write-json (hash 'success #f 'error (exn-message e)) (current-output-port))
        (newline)
        (exit 1))])

    ;; Generate grid specification
    (define spec (generate-grid-spec rows cols density mode))
    (define grid (hash-ref spec 'grid))
    (define start (hash-ref spec 'start))
    (define goal (hash-ref spec 'goal))

    ;; Run A* algorithm
    (define result (a-star grid start goal))

    ;; Convert to JSON format
    (define output (result->jsexpr grid start goal result))

    ;; Output JSON only (no other output)
    (write-json output (current-output-port))
    (newline)
    (exit 0)))

;; Run main
(main)
