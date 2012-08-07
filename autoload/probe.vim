" Match window
let s:max_height = 10
let s:height = 0
let s:location = 'botright'
let s:bufname = '--probe--'
let s:selection_marker = '> '
let s:marker_length = len(s:selection_marker)
let s:bufnr = -1

" Matching
let s:candidates = []
let s:index = 0 " s:candidates index
let s:matches = []
let s:selected = 0
let s:prompt_input = ''
let s:prev_prompt_input = ''
let s:ignore_case = '\c'
let s:show_scores = 0

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

" Scoring
let s:path_separators = '/'

" Finder functions (for finding files, buffers, etc.)
function! probe#noop()
endfunction
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
endfunction

function! s:setup_matches()
    let s:scores = repeat([0], s:max_height)
    let s:candidates = g:Probe_scan()
    let s:matches = s:candidates[: s:max_height-1]
    let s:selected = 0
    let s:index = s:max_height
    cal s:print_matches()
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
endfunction


function! probe#on_prompt_change(prompt_input)
    let s:prev_prompt_input = s:prompt_input
    let s:prompt_input = a:prompt_input
    cal s:update_matches()
endfunction

function! probe#select_next()
    let s:selected = s:selected <= 0 ? 0 : s:selected - 1
    cal s:print_matches()
endfunction

function! probe#select_prev()
    let s:selected = s:selected >= s:height-1 ? s:height-1 : s:selected + 1
    cal s:print_matches()
endfunction

function! probe#refresh_cache()
    let s:match_cache = {}
    cal g:Probe_refresh()
    cal g:Probe_scan()
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


function! s:update_matches()
    if has_key(s:match_cache, s:prompt_input)
        let [s:matches, s:index] = s:match_cache[s:prompt_input]
    else
        cal s:find_new_matches()
    endif

    if len(s:prompt_input) > 0
        let s:match_cache[s:prompt_input] = [s:matches, s:index]
        cal add(s:match_cache_order, s:prompt_input)
    endif
    if len(s:match_cache) > s:max_match_cache_size
        unlet s:match_cache[s:match_cache_order[0]]
        let s:match_cache_order = s:match_cache_order[1:]
    endif

    let s:selected = 0
    let s:matches = s:sort_matches_by_score(s:matches)
    cal s:print_matches()
endfunction

function! s:find_new_matches()
    let pattern = s:pattern(s:prompt_input)
    if len(s:prompt_input) >= len(s:prev_prompt_input)
        " See if the old matches are still valid.
        let s:matches = s:match(pattern, s:matches, 0, s:max_height)[0]
    else
        " Search is wider, so we need to go through all the candidates again.
        let s:index = 0
        let s:matches = []
    endif
    if len(s:matches) < s:max_height
        " Find any needed new matches.
        let needed = s:max_height - len(s:matches)
        let [fresh_matches, s:index] = s:match(pattern, s:candidates, s:index, needed)
        cal extend(s:matches, fresh_matches)
    endif
endfunction

function! s:match(pattern, candidates, start, needed)
    let needed = a:needed < 0 ? len(a:candidates) : a:needed

    let matches = []
    let i = a:start
    while i < len(a:candidates) && len(matches) < needed
        let candidate = a:candidates[i]
        if candidate =~? a:pattern
            cal add(matches, candidate)
        endif
        let i += 1
    endwhile
    return [matches, i]
endfunction

function! s:score_match(pattern, match)
" Score a match based on how close pattern characters match to path separators,
" other pattern characters, and the end of the match.
    let pattern = split(a:pattern, '\zs')
    let match = split(a:match, '\zs')
    let p_i = 0
    let m_i = 0
    let path_sep_dist = 0
    let char_match_dist = 100
    let score = 0
    while p_i < len(pattern) && m_i < len(match)
        let p_c = pattern[p_i]
        let m_c = match[m_i]

        let is_match = p_c == m_c

        if is_match
            let score += path_sep_dist == 0
            let score += char_match_dist == 0
            let score += m_i == (len(match) - 1)
        endif

        let is_path_sep = stridx(s:path_separators, m_c) != -1
        let path_sep_dist = is_path_sep ? 0 : path_sep_dist + 1
        let char_match_dist = is_match ? 0 : char_match_dist + 1
        let m_i += 1
        let p_i += is_match
    endwhile
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
" Sort [<score>, <match>] pairs by score and match length.
"
" It seems like shorter filenames tend to be what's desired, possibly due to
" the higher probability of an unintended match on a long filename, so for
" groups with the same score put the short filenames first.
    let score_delta = a:b[0] - a:a[0]
    if score_delta != 0
        return score_delta
    endif
    let length_delta = len(a:a[1]) - len(a:b[1])
    return length_delta
endfunction

" Easy to add other matching strategies, but the syntax highlighting would need
" to be different for each.
function! s:pattern(prompt_input)
    let pattern = [s:ignore_case, '^']
    for c in split(a:prompt_input, '\zs')
        cal add(pattern, printf('[^%s]*%s', c, c))
    endfor
    return join(pattern, '')
endfunction

function! s:print_matches()
    silent %delete
    let s:height = min([len(s:matches), s:max_height])
    exe printf('resize %d', s:height)
    if empty(s:matches)
        cal setline(1, '--NO MATCHES--')
        return
    endif

    let i = 1
    while i <= s:height
        let prefix = s:height-i == s:selected ? '> ' : '  '
        let match = s:matches[s:height - i]
        let score = s:scores[s:height - i]
        if s:show_scores
            let line = printf('%s%d %s', prefix, score, match)
        else
            let line = prefix . match
        endif
        cal setline(i, line)
        let i += 1
    endwhile
    cal cursor(s:height - s:selected, 1)
    cal s:update_statusline()
    cal s:highlight_matches()
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

    let i = 0
    while i < len(s:prompt_input)
        let preceding_chars = i == 0 ? '' : s:prompt_input[:i-1]
        let c = s:prompt_input[i]
        let pattern = printf('\v(%s[^%s]*)@<=%s', s:pattern(preceding_chars), c, c)
        cal matchadd('ProbeMatch', pattern)
        let i += 1
    endwhile
endfunction
