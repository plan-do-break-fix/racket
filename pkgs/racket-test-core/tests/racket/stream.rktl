
(load-relative "loadtest.rktl")

(Section 'stream)

(require racket/stream
         "for-util.rkt")

;; >>> Many basic stream tests are in "sequence.rktl" <<<

(test #f stream? '#(1 2))

(test 1 'stream-length (stream-length (stream-cons 1 empty-stream)))
(test 1 'stream-length (stream-length (stream 1)))

(define infinite-ones (stream-cons 1 infinite-ones))

(test 1 stream-first infinite-ones)
(test 1 stream-ref infinite-ones 100)

(test 1 stream-first (stream-cons 1 (let loop () (loop))))
(test 2 stream-length (stream-cons (let loop () (loop)) 
                                   (stream-cons (let loop () (loop)) 
                                                empty)))

(test #t stream-empty? (sequence->stream (in-producer void (void))))
(test #t stream-empty? (sequence->stream (in-port read-byte (open-input-string ""))))

(test "hello" stream-first (sequence->stream (in-producer (lambda () "hello") (void))))
(test 65 stream-first (sequence->stream (in-port read-byte (open-input-string "A"))))

(define one-to-four (stream 1 2 3 4))
(test 1 stream-first one-to-four)
(test 2 stream-ref one-to-four 1)
(test 3 stream-ref one-to-four 2)
(test 4 stream-ref one-to-four 3)
(test 2 'stream (stream-length (stream 1 (/ 0))))
(test 'a 'stream (stream-first (stream 'a (/ 0))))
(test 1 'stream* (stream-first (stream* (stream 1))))
(test 2 'stream* (stream-length (stream* 1 (stream (/ 0)))))
(test 'a 'stream* (stream-first (stream* 'a (stream (/ 0)))))
(test 4 'stream* (stream-length (stream* 'a 'b 'c (stream (/ 0)))))
(test 'c 'stream* (stream-first (stream-rest (stream-rest (stream* 'a 'b 'c (stream (/ 0)))))))
(err/rt-test (stream-force (stream* 2)) exn:fail:contract? "stream*")
(test #true 'stream* (stream? (stream* 1 0)))
(err/rt-test (stream-length (stream* 1 2)) exn:fail:contract? "stream*")

;; make sure stream operations work on lists
(test #t stream-empty? '())
(test 1 stream-first '(1 2 3))
(test '(2 3) stream-rest '(1 2 3))
(test 3 stream-length '(1 2 3))
(test 1 stream-ref '(1 2 3) 0)
(test '(2 3) stream-tail '(1 2 3) 1)
(test '(1 2) stream->list (stream-take '(1 2 3) 2))
(test '(1 2 3 4 5) stream->list (stream-append '(1 2 3) '(4 5)))
(test '(1 2 3) stream->list (stream-map values '(1 2 3)))
(test #f stream-andmap even? '(1 2 3))
(test #t stream-ormap even? '(1 2 3))
(test #t void? (stream-for-each void '(1 2 3)))
(test 6 stream-fold + 0 '(1 2 3))
(test 1 stream-count even? '(1 2 3))
(test '(1 3) stream->list (stream-filter odd? '(1 2 3)))
(test '(1 a 2 a 3) stream->list (stream-add-between '(1 2 3) 'a))

(test 4 'for/stream (stream-ref (for/stream ([x '(1 2 3)]) (* x x)) 1))
(test 6 'for*/stream (stream-ref (for*/stream ([x '(1 2 3)] [y '(1 2 3)]) (* x y)) 7))
(test 1 'for/stream (stream-first (for*/stream ([x '(1 0)]) (/ x))))
(test 625 'for/stream (stream-ref (for/stream ([x (in-naturals)]) (* x x)) 25))

;; for/stream should be lazy https://github.com/racket/racket/issues/2812
(test #true stream? (for/stream ((x '(0)) #:when (/ x x)) (void)))
(test #true stream? (for*/stream ((x '(0)) #:when (/ x x)) (void)))

(test '(0 1 2 3 4 5) stream->list (for/stream ([i (in-naturals)] #:break (> i 5)) i))
(test '(0 1 2 3 4 5) stream->list (for/stream ([i (in-naturals)]) #:break (> i 5) i))
(test '(0 1 2 3 4 5) stream->list (for/stream ([i (in-naturals)])
                                    (define ii (sqr i)) #:break (> ii 30) i))
(test-sequence [(1 2 3)] (for/list ([x (in-stream (stream 1 2 3))]) x))
(err/rt-test (for/list ([x (in-stream)]) x))
(err/rt-test (in-stream))

;; stream-take works on infinite streams with lazy-delayed errors later
(test '(1 4/3 4/2 4/1) stream->list
      (stream-take (let loop ([i 4])
                     (stream-cons (/ 4 i) (loop (sub1 i))))
                   4))
;; stream-take preserves laziness, doesn't evaluate elements too early
(define (guarded-second s)
  (if (stream-ref s 0) (stream-ref s 1) #f))
(define (div a b)
  (stream (not (zero? b)) (/ a b)))
(test #f guarded-second (stream-take (div 1 0) 2))
(test 3/4 guarded-second (stream-take (div 3 4) 2))
(err/rt-test (stream->list (stream-take (stream 1 2) 3)) exn:fail:contract? "stream-take")

;; preserves multivalued-ness of stream
(test '(1 2)
      call-with-values
      (λ ()
        (stream-first
         (stream-take
          (sequence->stream
           (in-parallel '(1 3) '(2 4))) 2)))
      list)

(test '(1 2)
      call-with-values
      (λ ()
        (stream-first
         (stream-map
          values
          (sequence->stream
           (in-parallel '(1 3) '(2 4))))))
      list)

(test '(1 2)
      call-with-values
      (λ ()
        (stream-first
         (stream-add-between
          (sequence->stream
           (in-parallel '(1 3) '(2 4)))
          #f)))
      list)

(test '(1 2)
      call-with-values
      (λ ()
        (stream-first
         (stream-filter
          (λ _ #t)
          (sequence->stream
           (in-parallel '(1 3) '(2 4))))))
      list)

;; check `#:eager`
(test #t stream? (stream-cons (/ 1 0) (/ 1 0)))
(test #t stream? (stream-cons #:eager 1 (/ 1 0)))
(test #t stream? (stream-cons (/ 1 0) #:eager '(1)))
(test #t stream? (stream-cons #:eager 0 #:eager '(1)))
(err/rt-test (stream-cons 1 #:eager (/ 1 0)))
(err/rt-test (stream-cons #:eager (/ 1 0) '(1)))
(err/rt-test (stream-cons #:eager (/ 1 0) #:eager '(1)))
(err/rt-test (stream-cons #:eager 1 #:eager (/ 1 0)))
(err/rt-test (stream-cons #:eager 1 #:eager 1))

;; stream-rest doesn't force rest expr
(test #t stream? (stream-rest (stream-cons 1 'oops)))

;; stream-force does force
(err/rt-test (stream-force (stream-rest (stream-cons 1 'oops))))
(err/rt-test (stream-empty? (stream-rest (stream-cons 1 'oops))))
(err/rt-test (stream-first (stream-rest (stream-cons 1 'oops))))
(err/rt-test (stream-rest (stream-rest (stream-cons 1 'oops))))

(test #t stream? (stream-lazy 'oops))
(err/rt-test (stream-force (stream-lazy 'oops)))
(err/rt-test (stream-empty? (stream-lazy 'oops)))
(err/rt-test (stream-first (stream-lazy 'oops)))
(err/rt-test (stream-rest (stream-lazy 'oops)))

(test #t stream? (stream* 'oops))
(err/rt-test (stream-force (stream* 'oops)))
(err/rt-test (stream-empty? (stream* 'oops)))
(err/rt-test (stream-first (stream* 'oops)))
(err/rt-test (stream-rest (stream* 'oops)))

(err/rt-test (stream-force (stream-lazy #:who 'alice 'oops))
             exn:fail:contract?
             #rx"^alice: ")

(test #f null? (stream-lazy '()))
(test #t null? (stream-force (stream-lazy '())))
(test #t stream-empty? (stream-lazy '()))

;; lazy forcing errors => stays erroring
(let ([s (stream-cons (error "oops") null)])
  (err/rt-test/once (stream-first s) exn:fail?)
  (err/rt-test (stream-first s) exn:fail:contract? #rx"reentrant or broken"))
(let ([s (stream-cons 0 (error "oops"))])
  (test #t stream? (stream-rest s))
  (err/rt-test/once (stream-empty? (stream-rest s)) exn:fail?)
  (err/rt-test (stream-empty? (stream-rest s)) exn:fail:contract? #rx"reentrant or broken"))

;; lazy forcing is non-reentrant
(letrec ([s (stream-cons (stream-first s) null)])
  (err/rt-test (stream-first s) exn:fail:contract? #rx"reentrant or broken"))
(letrec ([s (stream-cons 1 (stream-force (stream-rest s)))])
  (err/rt-test (stream-empty? (stream-rest s)) exn:fail:contract? #rx"reentrant or broken"))

;; regression test for chain of lazy streams
(test 1 stream-first (stream-lazy
                      (stream-lazy
                       (stream-lazy '(1)))))

(report-errs)
