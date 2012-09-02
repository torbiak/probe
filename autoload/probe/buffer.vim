function! probe#buffer#find()
    cal probe#open(
        \ function('probe#buffer#scan'),
        \ function('probe#buffer#open'),
        \ function('probe#buffer#refresh'))
endfunction

function! probe#buffer#scan()
    let buffers = []
    let max = bufnr('$')
    let i = 1
    while i <= max
        if buflisted(i) && bufname(i) != ''
            cal add(buffers, bufname(i))
        endif
        let i += 1
    endwhile
    return buffers
endfunction

function! probe#buffer#open(name)
    exe printf('buffer %s', a:name)
endfunction

function! probe#buffer#refresh()
    return
endfunction
