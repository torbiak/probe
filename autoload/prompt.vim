" public function prefix. Depends on prompt.vim location under autoload/.
let s:pre = 'prompt#'
let s:hooks = {}
let s:input = ''
let s:pos = 0

function! s:map_keys()
    " Basic keys that aren't customizable.
    let lowercase = 'abcdefghijklmnopqrstuvwxyz'
    let uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    let numbers = '0123456789'
    let punctuation = "<>`@#~!\"$%&/()=+*-_.,;:?\\\'{}[] " " and space
    for str in [lowercase, uppercase, numbers, punctuation]
        for key in split(str, '\zs')
            cal {s:pre}map_key(printf('<Char-%d>', char2nr(key)), s:pre . 'handle_key', key)
        endfor
    endfor

    " Special keys for common prompt operations.
    " All these commands can be overridden by including respective entries in the hooks dict.
    " Also, there are the following hooks:
    " - change: called whenever the input string changes
    let special = {
        \ 'accept'          : ['<CR>'],
        \ 'backspace'       : ['<BS>'],
        \ 'cancel'          : ['<C-c>', '<Esc>'],
        \ 'delete_to_start' : ['<C-u>'],
        \ 'delete_to_end'   : ['<C-k>'],
        \ 'cursor_end'      : ['<C-e>'],
        \ 'cursor_left'     : ['<Left>', '<C-b>'],
        \ 'cursor_right'    : ['<Right>', '<C-f>'],
        \ 'cursor_start'    : ['<C-a>'],
        \ 'delete'          : ['<Del>', '<C-d>'],
    \ }
    for [hook_name, keys] in items(special)
        for key in keys
            if key ==? '<Esc>' && &term =~ '\v(screen|xterm|vt100)'
                continue
            endif
            cal {s:pre}map_key(key, s:pre . 'handle_event', hook_name)
        endfor
    endfor
endfunction

function! {s:pre}map_key(key, func_name, ...)
    let args = empty(a:000) ? '' : string(join(a:000, ", "))
    exec printf("noremap <silent> <buffer> %s :call %s(%s)<cr>", a:key, a:func_name, args)
endfunction

function! s:split_input()
    let left = s:pos == 0 ? '' : s:input[: s:pos-1]
    let cursor = s:input[s:pos]
    let right = s:input[s:pos+1 :]
    return [left, cursor, right]
endfunction

function! {s:pre}render()
    redraw
    let [left, cursor, right] = s:split_input()

    echohl Comment
    echon '> '

    echohl None
    echon left

    echohl Underlined
    echon cursor == '' ? ' ' : cursor

    echohl None
    echon right
endfunction

function! {s:pre}handle_key(key)
    let [left, cursor, right] = s:split_input()
    let s:input = left . a:key . cursor . right
    let s:pos += 1
    cal {s:pre}render()
    cal s:change_hook()
endfunction

function! {s:pre}handle_event(hook)
    exec printf('cal %s%s()', s:pre, a:hook)
    if has_key(s:hooks, a:hook)
        cal s:hooks[a:hook]()
    endif
endfunction

function! {s:pre}open(hooks)
    " a:hooks - dict of funcrefs. eg.
    "   {'accept': function('myAccept'), 'change': function('myChange')}
    "   accept - <enter>
    "   change - a character is added or remove from the prompt's input
    let s:hooks = a:hooks
    cal s:map_keys()
    let s:input = ''
    let s:pos = 0
    cal {s:pre}render()
endfunction

function! {s:pre}close()
    redraw
    echo
    mapclear <buffer>
endfunction

function! s:change_hook()
    if has_key(s:hooks, 'change')
        cal s:hooks['change'](s:input)
    endif
endfunction

function! {s:pre}accept()
    cal {s:pre}close()
endfunction

function! {s:pre}backspace()
    if s:pos > 1
        let s:input = s:input[: s:pos-2] . s:input[s:pos :]
    else
        let s:input = s:input[s:pos :]
    endif
    let s:pos = s:pos == 0 ? 0 : s:pos-1
    cal {s:pre}render()
    cal s:change_hook()
endfunction

function! {s:pre}cancel()
    cal {s:pre}close()
endfunction

function! {s:pre}delete_to_start()
    let s:input = s:input[s:pos :]
    let s:pos = 0
    cal {s:pre}render()
    cal s:change_hook()
endfunction

function! {s:pre}delete_to_end()
    let s:input = s:pos == 0 ? '' : s:input[: s:pos-1]
    let s:pos = len(s:input)
    cal {s:pre}render()
    cal s:change_hook()
endfunction

function! {s:pre}cursor_end()
    let s:pos = len(s:input)
    cal {s:pre}render()
endfunction

function! {s:pre}cursor_left()
    if s:pos > 0
        let s:pos -= 1
        cal {s:pre}render()
    endif
endfunction

function! {s:pre}cursor_right()
    if s:pos < len(s:input)
        let s:pos += 1
        cal {s:pre}render()
    endif
endfunction

function! {s:pre}cursor_start()
    let s:pos = 0
    cal {s:pre}render()
endfunction

function! {s:pre}delete()
    if s:pos < len(s:input)
        let s:input = s:input[: s:pos-1] . s:input[s:pos+1 :]
        cal {s:pre}render()
        cal s:change_hook()
    endif
endfunction
