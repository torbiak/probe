let s:hooks = {}
let s:input = ''
let s:pos = 0

let s:default_key_bindings = {
    \ 'accept'          : ['<CR>'],
    \ 'backspace'       : ['<BS>'],
    \ 'backspace_word'  : ['<C-w>'],
    \ 'cancel'          : ['<C-c>', '<Esc>'],
    \ 'delete_to_start' : ['<C-u>'],
    \ 'delete_to_end'   : ['<C-k>'],
    \ 'cursor_end'      : ['<C-e>'],
    \ 'cursor_left'     : ['<Left>', '<C-b>'],
    \ 'cursor_right'    : ['<Right>', '<C-f>'],
    \ 'cursor_start'    : ['<C-a>'],
    \ 'delete'          : ['<Del>', '<C-d>'],
\}

function! s:map_keys(key_bindings)
" a:key_bindings override the defaults for "special" operations, like cursor
" control.

    " Basic keys that aren't customizable.
    let lowercase = 'abcdefghijklmnopqrstuvwxyz'
    let uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    let numbers = '0123456789'
    let punctuation = "<>`@#~!\"$%&/()=+*-_.,;:?\\\'{}[] " " and space
    for str in [lowercase, uppercase, numbers, punctuation]
        for key in split(str, '\zs')
            cal prompt#map_key(printf('<Char-%d>', char2nr(key)), 'prompt#handle_key', key)
        endfor
    endfor

    " Special keys for common prompt operations.
    " All these commands can be overridden by including respective entries in the hooks dict.
    " Also, there are the following hooks:
    " - change: called whenever the input string changes
    for [hook_name, keys] in items(s:default_key_bindings)
        if has_key(a:key_bindings, hook_name)
            unlet keys
            let keys = a:key_bindings[hook_name]
        endif
        if type(keys) != type([])
            let temp = keys
            unlet keys
            let keys = [temp]
        endif
        for key in keys
            if key ==? '<Esc>' && &term =~ '\v(screen|xterm|vt100)'
                continue
            endif
            cal prompt#map_key(key, 'prompt#handle_event', hook_name)
        endfor
    endfor
endfunction

function! prompt#map_key(key, func_name, ...)
    let args = empty(a:000) ? '' : string(join(a:000, ", "))
    exec printf("noremap <silent> <buffer> %s :call %s(%s)<cr>", a:key, a:func_name, args)
endfunction

function! s:split_input()
    let left = s:pos == 0 ? '' : s:input[: s:pos-1]
    let cursor = s:input[s:pos]
    let right = s:input[s:pos+1 :]
    return [left, cursor, right]
endfunction

function! prompt#render()
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

function! prompt#handle_key(key)
    let [left, cursor, right] = s:split_input()
    let s:input = left . a:key . cursor . right
    let s:pos += 1
    cal prompt#render()
    cal s:change_hook()
endfunction

function! prompt#handle_event(hook)
    exec printf('cal prompt#%s()', a:hook)
    if has_key(s:hooks, a:hook)
        cal s:hooks[a:hook]()
    endif
endfunction

function! prompt#open(hooks, key_bindings)
    " Operations can be overridden by giving functions via a:hooks.
    " Key bindings to operations can be overridden via a:key_bindings.
    "
    " a:hooks - dict of funcrefs. eg.
    "   {'accept': function('myAccept'), 'change': function('myChange')}
    "   accept - called when <enter> is pressed
    "   change - called when the prompt's input changes
    "
    " a:key_bindings - dict of key mappings to override defaults. eg.
    "   {'cancel': <c-q>}
    " See the 'special' dict in s:map_keys for available operations.
    let s:hooks = a:hooks
    cal s:map_keys(a:key_bindings)
    let s:input = ''
    let s:pos = 0
    cal prompt#render()
endfunction

function! prompt#close()
    redraw
    echo
    mapclear <buffer>
endfunction

function! s:change_hook()
    if has_key(s:hooks, 'change')
        cal s:hooks['change'](s:input)
    endif
endfunction

function! prompt#accept()
    cal prompt#close()
endfunction

function! prompt#backspace()
    if s:pos > 1
        let s:input = s:input[: s:pos-2] . s:input[s:pos :]
    else
        let s:input = s:input[s:pos :]
    endif
    let s:pos = s:pos == 0 ? 0 : s:pos-1
    cal prompt#render()
    cal s:change_hook()
endfunction

function! prompt#backspace_word()
" Delete the space-delimited word preceding the cursor, plus any spaces
" between the word and the cursor.
    if s:input == ''
        return
    end

    let new_pos = s:pos - 1
    while new_pos > 0 && s:input[new_pos] == ' '
        let new_pos -= 1
    endwhile
    while new_pos > 0 && s:input[new_pos] != ' '
        let new_pos -= 1
    endwhile

    let s:input = s:input[:new_pos] . s:input[s:pos :]
    let s:pos = new_pos + 1
    if new_pos == 0
        let s:input = ''
        let s:pos = 0
    endif

    cal prompt#render()
    cal s:change_hook()
endfunction

function! prompt#cancel()
    cal prompt#close()
endfunction

function! prompt#delete_to_start()
    let s:input = s:input[s:pos :]
    let s:pos = 0
    cal prompt#render()
    cal s:change_hook()
endfunction

function! prompt#delete_to_end()
    let s:input = s:pos == 0 ? '' : s:input[: s:pos-1]
    let s:pos = len(s:input)
    cal prompt#render()
    cal s:change_hook()
endfunction

function! prompt#cursor_end()
    let s:pos = len(s:input)
    cal prompt#render()
endfunction

function! prompt#cursor_left()
    if s:pos > 0
        let s:pos -= 1
        cal prompt#render()
    endif
endfunction

function! prompt#cursor_right()
    if s:pos < len(s:input)
        let s:pos += 1
        cal prompt#render()
    endif
endfunction

function! prompt#cursor_start()
    let s:pos = 0
    cal prompt#render()
endfunction

function! prompt#delete()
    if s:pos < len(s:input)
        let s:input = s:input[: s:pos-1] . s:input[s:pos+1 :]
        cal prompt#render()
        cal s:change_hook()
    endif
endfunction
