" Escaping entire paths to use as cache filenames seemed tricky and ugly
" and vim doesn't support bitwise operations, so multiplicative hashing
" looked attractive.
function! probe#util#rshash(string)
" Robert Sedgwick's hash function from Algorithms in C.
    let b = 378551
    let a = 63689
    let hash = 0
    for c in split(a:string, '\zs')
        let hash = hash * a + char2nr(c)
        let a = a * b
    endfor
    return hash
endfunction
