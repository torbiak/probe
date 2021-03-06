" Interactive line editing in the command-line mode area.

let s:history = []
let s:history_index = 0
let s:hooks = {}
let s:input = ''
let s:pos = 0
let s:saved_input = ''

let s:default_key_bindings = {
    \ 'accept'          : ['<CR>'],
    \ 'backspace'       : ['<BS>'],
    \ 'backspace_word'  : ['<C-w>'],
    \ 'cancel'          : ['<C-c>', '<Esc>'],
    \ 'delete_to_start' : ['<C-u>'],
    \ 'delete_to_end'   : ['<C-k>'],
    \ 'cursor_left'     : ['<Left>', '<C-b>'],
    \ 'cursor_right'    : ['<Right>', '<C-f>'],
    \ 'cursor_start'    : ['<C-a>', '<home>'],
    \ 'cursor_end'      : ['<C-e>', '<end>'],
    \ 'delete'          : ['<Del>', '<C-d>'],
    \ 'history_backward': ['<C-o>'],
    \ 'history_forward' : ['<C-i>'],
\}

function! prompt#open(hooks, key_bindings)
    " Open an interactive prompt.
    "
    " a:hooks - dict of funcrefs. eg.
    "   {'accept': function('myAccept'), 'change': function('myChange')}
    "   accept - called after <enter> is pressed
    "   cancel - called after <C-c> is pressed
    "   change - called whenever the prompt's input changes
    "
    " a:key_bindings - dict of key mappings to override defaults. eg.
    "   {'cancel': <c-q>}
    " See the s:default_key_bindings dict for available operations.
    let s:hooks = a:hooks
    cal s:map_keys(a:key_bindings)
    let s:input = ''
    let s:pos = 0
    let s:history_index = len(s:history)
    let s:saved_input = ''
    cal prompt#render()
endfunction

function! s:map_keys(key_bindings)
    " a:key_bindings overrides the defaults for "special" operations, like
    " cursor control.

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

    " Disable keys that can mess up the buffer.
    for key in ['<insert>']
        cal s:disable_key(key)
    endfor
endfunction

function! prompt#close()
    redraw
    echo
    mapclear <buffer>
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
    cal s:on_input_change()
endfunction

function! s:disable_key(key)
    exec printf("noremap <silent> <buffer> %s <nop>", a:key)
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

function! s:add_history(entry)
    if a:entry =~ '^\s*$'
        return
    endif
    if len(s:history) > 0 && a:entry ==# s:history[-1]
        return
    endif
    " Limit history to n entries.
    if len(s:history) >= 100
        let s:history = s:history[1:]
    endif
    cal add(s:history, a:entry)
    let s:history_index = len(s:history)
endfunction

function! prompt#handle_event(name)
    exec printf('cal prompt#%s()', a:name)
    if has_key(s:hooks, a:name)
        cal s:hooks[a:name]()
    endif
endfunction

function! s:on_input_change()
    let s:history_index = len(s:history)
    cal s:change_hook()
endfunction

function! s:change_hook()
    if has_key(s:hooks, 'change')
        cal s:hooks['change'](s:input)
    endif
endfunction

function! prompt#accept()
    cal s:add_history(s:input)
endfunction

function! prompt#backspace()
    if s:pos > 1
        let s:input = s:input[: s:pos-2] . s:input[s:pos :]
    else
        let s:input = s:input[s:pos :]
    endif
    let s:pos = s:pos == 0 ? 0 : s:pos-1
    cal prompt#render()
    cal s:on_input_change()
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
    cal s:on_input_change()
endfunction

function! prompt#cancel()
    cal prompt#close()
endfunction

function! prompt#delete_to_start()
    let s:input = s:input[s:pos :]
    let s:pos = 0
    cal prompt#render()
    cal s:on_input_change()
endfunction

function! prompt#delete_to_end()
    let s:input = s:pos == 0 ? '' : s:input[: s:pos-1]
    let s:pos = len(s:input)
    cal prompt#render()
    cal s:on_input_change()
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
        cal s:on_input_change()
    endif
endfunction

function! prompt#history_backward()
    if s:history_index == len(s:history)
        let s:saved_input = s:input
    endif
    if s:history_index > 0
        let s:history_index -= 1
        let s:input = s:history[s:history_index]
        let s:pos = len(s:input)
        cal prompt#render()
        cal s:change_hook()
    endif
endfunction

function! prompt#history_forward()
    if s:history_index > len(s:history) - 1
        return
    endif
    let s:history_index += 1
    if s:history_index < len(s:history)
        let s:input = s:history[s:history_index]
    elseif s:history_index == len(s:history)
        let s:input = s:saved_input
    endif
    let s:pos = len(s:input)
    cal prompt#render()
    cal s:change_hook()
endfunction
