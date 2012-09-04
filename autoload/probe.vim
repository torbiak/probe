" Match window
let g:probe_max_height = 10
let s:height = 0
let s:bufname = '--probe----o'
let s:bufnr = -1
let s:winnr = -1
let s:no_matches_message = '--NO MATCHES--'

" Debugging and tweaking info
let s:show_time_spent = 0

let s:candidates = []
let s:prompt_input = ''
let s:prev_prompt_input = ''

" Character-wise caching
let s:match_cache = {}
let s:match_cache_order = []
let s:max_match_cache_size = 10

" Key bindings
let s:default_key_bindings = {
    \ 'select_next': '<c-n>',
    \ 'select_prev': '<c-p>',
    \ 'accept_split': '<c-s>',
    \ 'accept_vsplit': '<c-v>',
    \ 'refresh_cache': ['<f5>', '<c-r>'],
    \ 'up_dir': '<c-y>',
\ }

" Finder functions (for finding files, buffers, etc.)
function! probe#noop()
endfunction
unlet! g:Probe_scan g:Probe_open g:Probe_refresh
let g:Probe_scan = function('probe#noop')
let g:Probe_open = function('probe#noop')
let g:Probe_refresh = function('probe#noop')


function! probe#open(scan, open, refresh)
    unlet! g:Probe_scan g:Probe_open g:Probe_refresh
    let g:Probe_scan = a:scan
    let g:Probe_open = a:open
    let g:Probe_refresh = a:refresh

    cal s:save_vim_state()
    cal s:create_buffer()
    cal s:set_options()

    cal prompt#open({
        \ 'accept': function('probe#accept_nosplit'),
        \ 'cancel': function('probe#close'),
        \ 'change': function('probe#on_prompt_change'),
    \ }, g:probe_mappings)

    cal s:create_cleanup_autocommands()
    cal s:map_keys()
    cal s:setup_highlighting()

    let s:prev_prompt_input = ''
    let s:prompt_input = ''
    let s:candidates = g:Probe_scan()
    let s:time_spent = 0.0 " for benchmarking
    cal s:update_matches()
endfunction

function! s:save_vim_state()
    cal s:save_options()
    let s:last_pattern = @/
    let s:winrestcmd = winrestcmd() " TODO: Support older versions of vim.
    let s:saved_window_num = winnr()
    let s:orig_working_dir = ''
endfunction

function! probe#set_orig_working_dir(dir)
    let s:orig_working_dir = a:dir
endfunction

function! s:set_options()
    set timeout          " ensure mappings timeout
    set timeoutlen=0     " respond immediately to mappings
    set nohlsearch       " don't highlight search strings
    set noinsertmode     " don't make Insert mode the default
    set noshowcmd        " don't show command info on last line
    set report=9999      " don't show 'X lines changed' reports
    set sidescroll=0     " don't sidescroll in jumps
    set sidescrolloff=0  " don't sidescroll automatically
    set noequalalways    " don't auto-balance window sizes
endfunction

function! s:create_buffer()
    if s:bufnr == -1
        exe printf('silent! keepalt %s 1split %s', g:probe_window_location, s:bufname)
        let s:bufnr = bufnr('%')
        let s:winnr = winnr()
        cal s:set_local_options()
    else " still have the buffer from last time
        exe printf('silent! %s sbuffer %d', g:probe_window_location, s:bufnr)
        resize 1
    endif
endfunction

function! s:create_cleanup_autocommands()
    " Always cleanup, regardless how the buffer is left.
    " (eg. <C-W q>, <C-W k>, etc)
    autocmd! * <buffer>'
    autocmd BufLeave <buffer> silent! probe#close()
    autocmd BufUnload <buffer> silent! probe#restore_vim_state()
endfunction

function! s:map_keys()
    unlet! keys
    for [operation, keys] in items(s:default_key_bindings)
        if has_key(g:probe_mappings, operation)
            unlet keys
            let keys = g:probe_mappings[operation]
        endif
        if type(keys) != type([])
            let temp = keys
            unlet keys
            let keys = [temp]
        endif
        for key in keys
            cal prompt#map_key(key, 'probe#' . operation)
        endfor
        unlet! keys
    endfor
endfunction

function! s:setup_highlighting()
    highlight link ProbeNoMatches Error
    syntax match ProbeNoMatches '^--NO MATCHES--$'
    highlight link ProbeMatch Underlined
    cal clearmatches()
endfunction

function! s:set_local_options()
    setlocal bufhidden=unload " unload buf when no longer displayed
    setlocal buftype=nofile   " buffer is not related to any file
    setlocal noswapfile       " don't create a swapfile
    setlocal nowrap           " don't soft-wrap
    setlocal nonumber         " don't show line numbers
    setlocal nolist           " don't use List mode (visible tabs etc)
    setlocal foldcolumn=0     " don't show a fold column at side
    setlocal foldlevel=99     " don't fold anything
    setlocal cursorline       " highlight line cursor is on
    setlocal nospell          " spell-checking off
    setlocal nobuflisted      " don't show up in the buffer list
    setlocal textwidth=0      " don't hard-wrap (break long lines)
    setlocal nomore           " don't pause when the command-line overflows
    if exists('+colorcolumn')
        setlocal colorcolumn=0
    endif
    if exists('+relativenumber')
        setlocal norelativenumber
    endif
endfunction

function! s:save_options()
    let s:timeoutlen = &timeoutlen
    let s:report = &report
    let s:sidescroll = &sidescroll
    let s:sidescrolloff = &sidescrolloff
    let s:timeout = &timeout
    let s:equalalways = &equalalways
    let s:hlsearch = &hlsearch
    let s:insertmode = &insertmode
    let s:showcmd = &showcmd
    let s:updatetime = &updatetime
endfunction

function! s:restore_options()
    let &timeoutlen = s:timeoutlen
    let &report = s:report
    let &sidescroll = s:sidescroll
    let &sidescrolloff = s:sidescrolloff
    let &timeout = s:timeout
    let &equalalways = s:equalalways
    let &hlsearch = s:hlsearch
    let &insertmode = s:insertmode
    let &showcmd = s:showcmd
    let &updatetime = s:updatetime
endfunction

function! probe#restore_vim_state()
    cal s:restore_options()
    let @/ = s:last_pattern
    if s:orig_working_dir != ''
        exe printf('cd %s', s:orig_working_dir)
    endif
    exe s:winrestcmd
    exe s:saved_window_num . 'wincmd w'
endfunction


function! probe#on_prompt_change(prompt_input)
    let s:prev_prompt_input = s:prompt_input
    let s:prompt_input = a:prompt_input
    cal s:update_matches()
endfunction

function! probe#select_next()
    normal! j
    cal prompt#render()
endfunction

function! probe#select_prev()
    normal! k
    cal prompt#render()
endfunction

function! probe#refresh_cache()
    let s:match_cache = {}
    cal s:reset_matches()
    cal g:Probe_refresh()
    let s:candidates = g:Probe_scan()
    cal s:update_matches()
endfunction


function! probe#unload_buffer()
    " bunload closes the buffer's window as well, but if the only other buffer
    " is unlisted VIM will refuse to unload the probe buffer unless it's
    " already closed.
    silent quit " quit in case the only other buffer is unlisted.
    exe 'silent! bunload! ' . s:bufnr
endfunction

function! probe#close()
    cal probe#unload_buffer()
    cal probe#restore_vim_state()
    " Since prompt isn't being closed the status line needs to be cleared.
    redraw
    echo
endfunction


" Need functions without arguments to make key mapping easier.
function! probe#accept_nosplit()
    cal probe#accept('')
endfunction

function! probe#accept_split()
    cal probe#accept('split')
endfunction

function! probe#accept_vsplit()
    cal probe#accept('vsplit')
endfunction

function! probe#accept(split)
    " Get match information before closing the probe buffer.
    let selection = s:selected_match()
    let num_matches = s:num_matches()
    let dir = getcwd()
    cal probe#close()

    if num_matches > 0
        cal s:select_appropriate_window()
        if a:split ==? 'split' || &modified
            split
        endif
        if a:split ==? 'vsplit'
            vsplit
        endif
        cal g:Probe_open(dir . '/' . selection)
    endif
endfunction


function! s:select_appropriate_window()
" select the first normal-ish window.
    let initial = winnr()
    while 1
        if &buflisted || &buftype !=? 'nofile'
            return
        endif
        wincmd w
        if initial == winnr()
            return " Give up after cycling through all the windows.
        endif
    endwhile
endfunction

function! s:cache_matches()
    let pattern = s:prompt_input
    if len(s:prompt_input) > 0
        let s:match_cache[pattern] = getbufline(s:bufnr, 0, '$')
        cal add(s:match_cache_order, pattern)
    endif
    if len(s:match_cache) > s:max_match_cache_size
        let oldest_key = s:match_cache_order[0]
        let s:match_cache_order = s:match_cache_order[1:]
        if count(s:match_cache_order, oldest_key) == 0
            cal remove(s:match_cache, oldest_key)
        endif
    endif
endfunction

function! s:filter()
    if s:num_matches() > 0 && len(s:prompt_input) > 0
        exe printf('silent! g!#%s#d', escape(s:pattern(s:prompt_input), '#'))
    endif
endfunction

function! s:update_matches()
    let start_time = reltime()
    if has_key(s:match_cache, s:prompt_input)
        silent! %delete
        cal setline(1, s:match_cache[s:prompt_input])
    elseif s:is_search_narrower()
        cal s:filter()
    else
        cal s:reset_matches()
        cal s:filter()
    endif
    cal s:cache_matches()

    let nmatches = s:num_matches()
    if nmatches < g:probe_scoring_threshold && nmatches > 0
        " Scoring is expensive, so only do it when the search is narrow.
        let sorted = s:sort_matches_by_score(getbufline(s:bufnr, 0, '$'))
        silent! %delete
        cal setline(1, sorted)
    elseif s:num_matches() == 0
        cal setline(1, s:no_matches_message)
    endif

    exe printf('resize %d', min([s:num_matches(), g:probe_max_height]))
    cal s:update_statusline()
    cal s:highlight_matches()
    if g:probe_reverse_sort
        0
        normal! zt
    else
        $
        normal! zb
    endif
    let s:time_spent += str2float(reltimestr(reltime(start_time)))
endfunction

function! s:num_matches()
    if line('$') == 1 && getline(1) == ''
        return 0
    else
        return line('$')
    endif
endfunction

function! s:selected_match()
    if s:num_matches() == 0
        throw 'probe: no matches'
    endif
    return getline('.')
endfunction

function! s:smartcase()
    return s:prompt_input =~ '\u' ? '\C' : '\c'
endfunction

function! s:reset_matches()
    exe printf('resize %d', min([len(s:candidates), g:probe_max_height]))
    silent! %delete
    cal setline(1, s:candidates)
endfunction

function! s:is_search_narrower()
    let pattern = s:pattern(s:prompt_input)
    let is_longer = len(s:prompt_input) > len(s:prev_prompt_input)
    let appended_to_end = stridx(s:prompt_input, s:prev_prompt_input) == 0
    return is_longer && appended_to_end
endfunction

function! probe#score_match(pattern, match)
" Score a match based on how close pattern characters match to path separators,
" other pattern characters, and the end of the match.
    let match = a:match
    let pattern = a:pattern
    if s:smartcase() ==# '\c'
        let match = tolower(match)
        let pattern = tolower(pattern)
    endif

    if stridx(pattern, ' ') == -1
        let substrings = split(pattern, '\zs')
    else
        let substrings = split(pattern, ' \+')
    endif
    return s:score_substrings(substrings, match)
endfunction

function! s:score_substrings(substrings, match)
    let score = 0
    let prev_i = 0
    let i = 0

    for substring in a:substrings
        let i = stridx(a:match, substring, prev_i)
        if i == -1
            let i = prev_i
            continue
        endif
        if i == 0 || s:is_path_separator(a:match[i - 1])
            let score += 1
        endif
        if i == len(a:match) - 1
            let score += 1
        endif
        if prev_i && prev_i == i - 1
            let score += 1
        endif
        let prev_i = i
    endfor
    return score
endfunction

function! s:pattern(prompt_input)
    if stridx(s:prompt_input, ' ') == -1
        let pattern = ['\V\^', s:smartcase()]
        for c in split(a:prompt_input, '\zs')
            cal add(pattern, printf('\[^%s]\*%s', c, c))
        endfor
        return join(pattern, '')
    else
        return '\V' . s:smartcase() . join(split(a:prompt_input), '\.\*')
    endif
endfunction

function! s:sort_matches_by_score(matches)
    let rankings = []
    for match in a:matches
        let score = probe#score_match(s:prompt_input, match)
        cal add(rankings, [score, match])
    endfor
    let sorted = []
    for pair in sort(rankings, function('s:ranking_compare'))
        cal add(sorted, pair[1])
    endfor
    return sorted
endfunction

function! s:ranking_compare(a, b)
" Sort [<score>, <match>] pairs by score, match length.
    let score_delta = a:a[0] - a:b[0]
    if score_delta != 0
        return score_delta
    endif
    let length_delta = len(a:b[1]) - len(a:a[1])
    return length_delta
endfunction

function! s:update_statusline()
    let format = ''

    if g:Probe_scan == function('probe#file#scan')
        let format .= getcwd()
    else
        let format .= '--probe----o '
    endif

    let format .= '%='

    if s:num_matches() > g:probe_scoring_threshold
        let format .= '%#Special#%L%#StatusLine# matches'
    else
        let format .= '%L matches'
    endif
    if s:show_time_spent
        let format .= printf(' in %.2fs', s:time_spent)
    endif
    exe printf('setlocal stl=%s', escape(format, ' '))
endfunction

function! s:highlight_matches()
" Adds syntax matches to help visualize what's being matched.
"
" The accuracy of the highlighting depends on how closely it mimics the
" matching strategy (ie. the result of s:pattern), of course.
"
" For each character in the prompt input add a highlight match (matchadd) for
" its first occurence in the filename.
    nohlsearch
    cal clearmatches()
    if s:num_matches() == 0
        return
    endif

    if stridx(s:prompt_input, ' ') == -1
        let i = 0
        while i < len(s:prompt_input)
            let preceding_chars = i == 0 ? '' : s:prompt_input[:i-1]
            let c = s:prompt_input[i]
            let pattern = printf('\V\(%s\[^%s]\*\)\@<=%s', s:pattern(preceding_chars), c, c)
            cal matchadd('ProbeMatch', pattern)
            let i += 1
        endwhile
    else
        for token in split(s:prompt_input)
            let pattern = printf('\v(.{-})@<=%s', s:pattern(token))
            cal matchadd('ProbeMatch', pattern)
        endfor
    endif
endfunction

function! s:is_path_separator(char)
    return a:char =~ '[/\\]'
endfunction

function! probe#up_dir()
    if s:orig_working_dir == ''
        cal probe#set_orig_working_dir(getcwd())
    endif
    exe printf('cd %s', fnamemodify(getcwd(), ':h'))
    let s:candidates = g:Probe_scan()
    cal s:update_matches()
endfunction
