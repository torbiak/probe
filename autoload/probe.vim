" Match window
let s:max_height = 10
let s:height = 0
let s:location = 'botright'
let s:bufname = '--probe--'
let s:selection_marker = '> '
let s:marker_length = len(s:selection_marker)
let s:bufnr = -1

" Matching
" probe does an incremental search, but only scans the candidates once. It
" does this by only finding as many matches as it needs to fill the match
" window, keeping track of the matches and position in the candidates list as
" the prompt input narrows the search.
" Invariant: s:matches must always hold any matches for s:prompt_input in
" s:candidates[: s:index - 1].
let s:candidates = []
let s:index = 0 " s:candidates index
let s:matches = []
let s:scores = []
let s:prompt_input = ''
let s:prev_prompt_input = ''
let s:selected = 0
let s:ignore_case = '\c'
let s:show_scores = 1

" Character-wise caching
let s:match_cache = {}
let s:match_cache_order = []
let s:max_match_cache_size = 200

" Variables for saving global options.
let s:timeoutlen = 0
let s:report = 0
let s:sidescroll = 0
let s:sidescrolloff = 0
let s:timeout = 0
let s:equalalways = 0
let s:hlsearch = 0
let s:insertmode = 0
let s:showcmd = 0

let s:winrestcmd = '' " For saving window sizes.
let s:saved_window_num = 0 " Previously active window.

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
    cal s:set_options()
    cal s:create_buffer()

    cal prompt#open({
        \ 'accept': function('probe#accept_nosplit'),
        \ 'cancel': function('probe#close'),
        \ 'change': function('probe#on_prompt_change'),
    \ })

    cal s:create_cleanup_autocommands()
    cal s:map_keys()
    cal s:setup_matches()
    cal s:setup_highlighting()
endfunction

function! s:save_vim_state()
    cal s:save_options()
    let s:winrestcmd = winrestcmd() " TODO: Support older versions of vim.
    let s:saved_window_num = winnr()
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
        exe printf('silent! %s 1split %s', s:location, s:bufname)
        let s:bufnr = bufnr('%')
        cal s:set_local_options()
    else " still have the buffer from last time
        exe printf('silent! %s sbuffer %d', s:location, s:bufnr)
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
    cal prompt#map_key('<c-n>', 'probe#select_next')
    cal prompt#map_key('<c-p>', 'probe#select_prev')
    cal prompt#map_key('<c-s>', 'probe#accept', 'split')
    cal prompt#map_key('<c-v>', 'probe#accept', 'vsplit')
    cal prompt#map_key('<F5>',  'probe#refresh_cache')
    unmap <buffer> ;
    cal prompt#map_key(';',  'probe#score_all_matches')
endfunction

function! s:setup_matches()
    let s:candidates = g:Probe_scan()
    let s:matches = s:sort_matches_by_score(s:candidates[: s:max_height-1])
    let s:selected = 0
    let s:index = s:max_height
    cal s:render()
endfunction

function! s:setup_highlighting()
    highlight link ProbeNoMatches Error
    syntax match ProbeNoMatches '^--NO MATCHES--$'
    highlight link ProbeMatch Search
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
    setlocal nocursorline     " don't highlight line cursor is on
    setlocal nospell          " spell-checking off
    setlocal nobuflisted      " don't show up in the buffer list
    setlocal textwidth=0      " don't hard-wrap (break long lines)
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
    exe s:winrestcmd
    exe s:saved_window_num . 'wincmd w'
endfunction


function! probe#on_prompt_change(prompt_input)
    let s:prev_prompt_input = s:prompt_input
    let s:prompt_input = a:prompt_input
    cal s:update_matches()
endfunction

function! probe#select_next()
    let s:selected = s:selected <= 0 ? 0 : s:selected - 1
    cal s:render()
endfunction

function! probe#select_prev()
    let s:selected = s:selected >= s:height-1 ? s:height-1 : s:selected + 1
    cal s:render()
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

" Need a function without arguments to give to prompt.
function! probe#accept_nosplit()
    cal probe#accept('')
endfunction

function! probe#accept(split)
    cal probe#close()
    if !empty(s:matches)
        cal s:select_appropriate_window()
        if a:split ==? 'split' || &modified
            split
        endif
        if a:split ==? 'vsplit'
            vsplit
        endif
        cal g:Probe_open(s:matches[s:selected])
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

function! probe#score_all_matches()
    if len(s:prompt_input) == 0
        return
    endif
    let s:matches = s:sort_matches_by_score(s:find_all_matches())
    cal s:cache_matches()
    let s:selected = 0
    cal s:render()
endfunction

function! s:cache_matches()
    let pattern = s:pattern(s:prompt_input)
    if len(s:prompt_input) > 0
        let s:match_cache[pattern] = [s:matches, s:index]
        cal add(s:match_cache_order, pattern)
    endif
    if len(s:match_cache) > s:max_match_cache_size
        unlet s:match_cache[s:match_cache_order[0]]
        let s:match_cache_order = s:match_cache_order[1:]
    endif
endfunction

function! s:update_matches()
    let s:scores = []
    let pattern = s:pattern(s:prompt_input)
    if has_key(s:match_cache, pattern)
        let [s:matches, s:index] = s:match_cache[pattern]
    elseif s:is_search_narrower()
        let s:matches = s:find_carryforward_matches()
        let needed = s:max_height - len(s:matches)
        let needed = needed > 0 ? needed : 0
        cal extend(s:matches, s:find_new_matches(needed))
        let s:matches = s:sort_matches_by_score(s:matches)
        cal s:cache_matches()
    else
        cal s:reset_matches()
        let s:matches = s:find_new_matches(s:max_height)
        let s:matches = s:sort_matches_by_score(s:matches)
        cal s:cache_matches()
    endif

    let s:selected = 0
    cal s:render()
endfunction

function! s:reset_matches()
    let s:index = 0
    let s:matches = []
    let s:scores = []
endfunction

function! s:find_all_matches()
    let matches = s:find_carryforward_matches()
    cal extend(matches, s:find_new_matches(-1))
    return matches
endfunction

function! s:find_carryforward_matches()
    " This function assumes that the entries in s:matches match the current
    " prompt input.
    let pattern = s:pattern(s:prompt_input)
    return s:match(pattern, s:matches, 0, -1, s:max_height)[0]
endfunction

function! s:find_new_matches(count)
    " This function assumes that s:index is consistent with s:matches and the
    " prompt input.
    let pattern = s:pattern(s:prompt_input)
    let [new_matches, s:index] = s:match(pattern, s:candidates, s:index, -1, a:count)
    return new_matches
endfunction

function! s:is_search_narrower()
    let pattern = s:pattern(s:prompt_input)
    let is_longer = len(s:prompt_input) >= len(s:prev_prompt_input)
    let appended_to_end = stridx(s:prompt_input, s:prev_prompt_input) == 0
    return is_longer && appended_to_end
endfunction

function! s:match(pattern, candidates, start, stop, needed)
    let needed = a:needed >= 0 ? a:needed : len(a:candidates)
    let stop = a:stop > a:start ? a:stop : len(a:candidates)

    let matches = []
    let i = a:start
    while i < len(a:candidates) && i < stop && len(matches) < needed
        let candidate = a:candidates[i]
        if candidate =~? a:pattern
            cal add(matches, candidate)
        endif
        let i += 1
    endwhile
    return [matches, i]
endfunction

function! s:score_match(prompt_input, match)
    let score = 0
    for token in split(a:prompt_input)
        let pos = match(a:match, s:pattern(token))
        if pos == 0
            " at the beginning of the match
            let score += 1
        endif

        if pos > 0 && s:is_path_separator(a:match[pos-1])
            " right after a path separator
            let score += 1
        endif

        if len(token) + pos == len(a:match)
             " at the end of the match
            let score += 1
        endif
    endfor
    return score
endfunction

function! s:sort_matches_by_score(matches)
    let rankings = []
    for match in a:matches
        let score = s:score_match(s:prompt_input, match)
        cal add(rankings, [score, match])
    endfor
    let sorted = []
    let s:scores = []
    for pair in sort(rankings, function('s:ranking_compare'))
        cal add(sorted, pair[1])
        cal add(s:scores, pair[0])
    endfor
    return sorted
endfunction

function! s:ranking_compare(a, b)
" Sort [<score>, <match>] pairs by score, match length.
    let score_delta = a:b[0] - a:a[0]
    if score_delta != 0
        return score_delta
    endif
    let length_delta = len(a:a[1]) - len(a:b[1])
    return length_delta
endfunction

function! s:pattern(prompt_input) " tokenwise
    return '\V' . s:ignore_case . join(split(a:prompt_input), '\.\*')
endfunction

function! s:render()
    silent %delete
    let s:height = min([len(s:matches), s:max_height])
    exe printf('resize %d', s:height > 0 ? s:height : 1)

    if empty(s:matches)
        cal clearmatches()
        cal setline(1, '--NO MATCHES--')
    else
        cal s:print_matches()
        cal cursor(s:height - s:selected, 1)
        cal s:update_statusline()
        cal s:highlight_matches()
    endif

    cal s:update_statusline()
endfunction

function! s:print_matches()
    let i = 1
    while i <= s:height
        let prefix = s:height-i == s:selected ? '> ' : '  '
        let match = s:matches[s:height - i]
        if s:show_scores && !empty(s:scores)
            let score = s:scores[s:height - i]
            let line = printf('%s%d %s', prefix, score, match)
        else
            let line = prefix . match
        endif
        cal setline(i, line)
        let i += 1
    endwhile
endfunction

function! s:update_statusline()
    let percent_searched = float2nr((100.0 * s:index) / len(s:candidates))
    exe printf('setlocal stl=--probe--%%=%d\ matches\ out\ of\ %d\ (%d%%%%\ searched)',
        \ len(s:matches), len(s:candidates), percent_searched)
endfunction

function! s:highlight_matches()
" Adds syntax matches to help visualize what's being matched.
"
" The accuracy of the highlighting depends on how closely it mimics the
" matching strategy (ie. the result of s:pattern), of course.
"
" For each character in the prompt input add a highlight match (matchadd) for
" its first occurence in the filename.
    cal clearmatches()
    if empty(s:matches)
        return
    endif

    for token in split(s:prompt_input)
        let pattern = printf('\v(.{-})@<=%s', s:pattern(token))
        cal matchadd('ProbeMatch', pattern)
    endfor
endfunction

function! s:is_path_separator(char)
    return a:char =~ '[/\\]'
endfunction
