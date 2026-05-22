#lang racket

;;
;; GRID GENERATION MODULE
;;
;; Generates random grids of any size for testing A* pathfinding.
;; This allows testing without modifying code.
;;

(provide generate-random-grid
         generate-grid-with-obstacles
         generate-solvable-grid
         generate-blocked-grid
         find-empty-cell
         generate-grid-spec)

;;
;; Generate a random grid with specified dimensions and obstacle density.
;;
;; Parameters:
;;   rows: number of rows (height)
;;   cols: number of columns (width)
;;   obstacle-density: probability of obstacle (0.0 to 1.0)
;;
;; Returns: a grid (list of lists) where 0 = free, 1 = obstacle
;;
;; The first and last cells are always free to ensure valid start/goal.
;;
(define (generate-random-grid rows cols obstacle-density)
  (build-list rows
    (lambda (row)
      (build-list cols
        (lambda (col)
          ;; Always keep corners free for start and goal
          (if (or (and (= row 0) (= col 0))
                  (and (= row (- rows 1)) (= col (- cols 1))))
              0
              ;; Randomly decide if this cell is obstacle
              (if (< (random) obstacle-density) 1 0)))))))

;;
;; Generate a grid with specific obstacle density (0.0 to 1.0).
;;
;; Parameters:
;;   rows: number of rows
;;   cols: number of columns
;;   density: 0.0 = no obstacles, 1.0 = all obstacles
;;
;; Returns: grid where cells are 0 (free) or 1 (obstacle)
;;
(define (generate-grid-with-obstacles rows cols density)
  (generate-random-grid rows cols (max 0 (min 1 density))))

;;
;; Change one cell in a grid without mutating the original grid.
;;
;; Racket lists are immutable in this project style, so this function
;; builds a new grid where only the selected row and column are replaced.
;;
(define (set-cell grid target-row target-col value)
  (build-list (length grid)
    (lambda (row)
      (build-list (length (list-ref grid row))
        (lambda (col)
          (if (and (= row target-row) (= col target-col))
              value
              (list-ref (list-ref grid row) col)))))))

;;
;;
;; Build a random path from the top-left corner to the bottom-right corner.
;;
;; The path first chooses random intermediate waypoints. It then connects
;; each pair of points with horizontal and vertical moves. This still
;; guarantees that the start can reach the goal, but avoids the common
;; "almost diagonal" shape produced by only shuffling right/down moves.
;;
(define (random-guaranteed-path rows cols)
  (define waypoint-count (+ 2 (random 3)))
  (define waypoints
    (append
     (list '(0 0))
     (build-list waypoint-count
       (lambda (_)
         (list (random rows) (random cols))))
     (list (list (- rows 1) (- cols 1)))))

  (define (step-toward current target)
    (define current-row (first current))
    (define current-col (second current))
    (define target-row (first target))
    (define target-col (second target))
    (define vertical-move
      (cond
        [(< current-row target-row) (list (+ current-row 1) current-col)]
        [(> current-row target-row) (list (- current-row 1) current-col)]
        [else #f]))
    (define horizontal-move
      (cond
        [(< current-col target-col) (list current-row (+ current-col 1))]
        [(> current-col target-col) (list current-row (- current-col 1))]
        [else #f]))
    (define options (filter values (list vertical-move horizontal-move)))
    (list-ref options (random (length options))))

  (define (connect-points start target)
    (define (walk current path)
      (if (equal? current target)
          (reverse path)
          (let ([next-position (step-toward current target)])
            (walk next-position (cons next-position path)))))
    (walk start (list start)))

  (define (append-without-duplicate-prefix left right)
    (cond
      [(empty? left) right]
      [(empty? right) left]
      [(equal? (last left) (first right)) (append left (rest right))]
      [else (append left right)]))

  (define (walk-waypoints points path)
    (cond
      [(empty? (rest points)) path]
      [else
       (define segment (connect-points (first points) (second points)))
       (walk-waypoints (rest points)
                       (append-without-duplicate-prefix path segment))]))

  (walk-waypoints waypoints '()))

;;
;; Open the selected path in the grid.
;;
;; The input grid is not mutated. Each path cell is changed to 0 in the
;; new grid returned by this function.
;;
(define (carve-path grid path)
  (foldl (lambda (position current-grid)
           (set-cell current-grid (first position) (second position) 0))
         grid
         path))

;;
;; Open a few cells next to the guaranteed path.
;;
;; This keeps the generated grid from looking like one thin corridor and
;; gives A* more natural alternatives to explore.
;;
(define (carve-near-path grid path density)
  (define rows (length grid))
  (define cols (length (first grid)))
  (define opening-chance (max 0.08 (- 0.35 (* density 0.35))))
  (foldl
   (lambda (position current-grid)
     (define row (first position))
     (define col (second position))
     (define candidates
       (filter (lambda (candidate)
                 (and (>= (first candidate) 0)
                      (>= (second candidate) 0)
                      (< (first candidate) rows)
                      (< (second candidate) cols)))
               (list (list (- row 1) col)
                     (list (+ row 1) col)
                     (list row (- col 1))
                     (list row (+ col 1)))))
     (if (and (not (empty? candidates)) (< (random) opening-chance))
         (let ([chosen (list-ref candidates (random (length candidates)))])
           (set-cell current-grid (first chosen) (second chosen) 0))
         current-grid))
   grid
   path))

;;
;; Generate a random grid that is guaranteed to have at least one path.
;;
(define (generate-solvable-grid rows cols density)
  (define base-grid (generate-grid-with-obstacles rows cols density))
  (define path (random-guaranteed-path rows cols))
  (carve-near-path (carve-path base-grid path) path density))

;;
;; Generate a grid that is guaranteed to have no path.
;;
;; The start and goal stay free, but the start is isolated by blocking
;; its only two possible exits: right and down.
;;
(define (generate-blocked-grid rows cols density)
  (define base-grid (generate-grid-with-obstacles rows cols density))
  (define start-open (set-cell base-grid 0 0 0))
  (define goal-open (set-cell start-open (- rows 1) (- cols 1) 0))
  (define right-blocked (set-cell goal-open 0 1 1))
  (set-cell right-blocked 1 0 1))

;;
;; Find the first empty (free) cell in a grid.
;;
;; Returns: position [row col] of first free cell, or #f if none found
;;
(define (find-empty-cell grid)
  (define (search-rows row-idx)
    (cond
      [(>= row-idx (length grid)) #f]
      [else
       (define (search-cols col-idx)
         (cond
           [(>= col-idx (length (list-ref grid row-idx))) #f]
           [(= (list-ref (list-ref grid row-idx) col-idx) 0)
            (list row-idx col-idx)]
           [else (search-cols (+ col-idx 1))]))
       (define col-result (search-cols 0))
       (if col-result col-result (search-rows (+ row-idx 1)))]))
  (search-rows 0))

;;
;; Generate a grid specification that includes start and goal positions.
;;
;; Returns: hash with keys 'grid, 'start, 'goal
;;
;; The start position is the top-left corner (0,0).
;; The goal position is the bottom-right corner.
;;
(define (generate-grid-spec rows cols density [mode "random"])
  (define grid
    (cond
      [(equal? mode "solvable") (generate-solvable-grid rows cols density)]
      [(equal? mode "blocked") (generate-blocked-grid rows cols density)]
      [else (generate-grid-with-obstacles rows cols density)]))
  (define start '(0 0))
  (define goal (list (- rows 1) (- cols 1)))

  (hash 'grid grid
        'rows rows
        'cols cols
        'start start
        'goal goal
        'density density
        'mode mode))

;; For command-line testing:
;; (module+ main
;;   (define spec (generate-grid-spec 10 10 0.3))
;;   (displayln spec))
