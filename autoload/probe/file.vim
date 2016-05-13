" File-finder. Scan dirs, cache file lists, and open selected files.

" File caching vars
" If g:probe_cache_repo_branches is set repository caches are indexed by root
" directory and VCS branch, while normal (ie. directories without a VCS metadir
" or directories scanned using probe#file#find instead of
" probe#file#find_in_repo) are indexed by path.
let s:file_caches = {}
let s:file_cache_order = []
let s:max_file_caches = 10
let s:hash = ''

function! probe#file#find()
    let s:hash = probe#util#rshash(getcwd())
    cal probe#open(
        \ function('probe#file#scan'),
        \ function('probe#file#open'),
        \ function('probe#file#clear_cache'))
endfunction

function! probe#file#find_in_repo()
    let repo_root = s:find_repo_root()
    if repo_root == ''
        cal probe#file#find()
        return
    endif
    let orig_dir = getcwd()
    exe printf('cd %s', repo_root)
    if g:probe_cache_repo_branches
        let s:hash = probe#util#rshash(repo_root . s:branch())
    else
        let s:hash = probe#util#rshash(repo_root)
    endif
    cal probe#open(
        \ function('probe#file#scan'),
        \ function('probe#file#open'),
        \ function('probe#file#clear_cache'))
    cal probe#set_orig_working_dir(orig_dir)
endfunction

function! probe#file#scan()
    " use cache if possible
    if has_key(s:file_caches, s:hash)
        return s:file_caches[s:hash]
    endif
    let cache_filepath = s:cache_filepath()
    if g:probe_cache_dir != '' && filereadable(cache_filepath)
        let s:file_caches[s:hash] = readfile(cache_filepath)
        return s:file_caches[s:hash]
    endif

    " init new cache
    if !has_key(s:file_caches, s:hash)
        let s:file_caches[s:hash] = []
        cal add(s:file_cache_order, s:hash)
    endif

    " pare caches
    if len(s:file_caches) > s:max_file_caches
        unlet s:file_caches[s:file_cache_order[0]]
        let s:file_cache_order = s:file_cache_order[1:]
    endif

    " recursively scan for files
    let s:file_caches[s:hash] = s:scan_files(getcwd(), [], 0, {})

    if g:probe_cache_dir != ''
        cal s:save_cache(s:cache_filepath(), s:file_caches[s:hash])
    endif

    cal prompt#render()
    return s:file_caches[s:hash]
endfunction

function! probe#file#open(filepath)
    let filepath = escape(a:filepath, '\\|%# "')
    exe printf('edit %s', filepath)
endfunction

function! probe#file#clear_cache()
    if has_key(s:file_caches, s:hash)
        unlet s:file_caches[s:hash]
    endif
    cal delete(s:cache_filepath())
endfunction


" Each directory is only scanned once, so if multiple symlinks link to the same
" directory only filepaths via one of the symlinks will end up being returned.
" Hopefully this isn't surprising. Other ways of dealing with circular symlinks
" had more serious problems.
function! s:scan_files(dir, files, current_depth, scanned_dirs)
    let resolved_dir = resolve(fnamemodify(a:dir, ':p:h'))
    if has_key(a:scanned_dirs, resolved_dir)
        return a:files
    else
        let a:scanned_dirs[resolved_dir] = 1
    endif

    " scan dir recursively
    redraw
    echo "Scanning " . a:dir
    for name in split(globpath(a:dir, '*', !g:probe_use_wildignore), '\n')
        if len(a:files) >= g:probe_max_file_cache_size
            break
        endif
        if s:match_some(name, g:probe_ignore_files)
            continue
        endif
        if isdirectory(name)
            cal s:scan_files(name, a:files, a:current_depth+1, a:scanned_dirs)
            continue
        endif
        cal add(a:files, fnamemodify(name, ':.'))
    endfor

    return a:files
endfunction

function! s:match_some(str, patterns)
    for pattern in a:patterns
        if a:str =~# pattern
            return 1
        endif
    endfor
    return 0
endfunction

function! s:save_cache(filename, files)
    if !isdirectory(g:probe_cache_dir)
        cal mkdir(g:probe_cache_dir, 'p')
    endif
    cal writefile(a:files, a:filename)
endfunction

function! s:cache_filepath()
    return printf('%s/%s', g:probe_cache_dir, s:hash)
endfunction

function! s:find_metadir()
    let metadir_pattern = '\v/\.(git|hg|svn|bzr)\n'
    let orig_dir = getcwd()
    let dir = orig_dir
    while 1
        let metadir = matchstr(globpath(dir, '.*', 1), metadir_pattern)
        if metadir != ''
            return dir . s:strip(metadir)
        endif
        let parent = fnamemodify(dir, ':h')
        if parent ==# dir
            return ''
        endif
        let dir = parent
    endwhile
endfunction

function! s:strip(string)
    return substitute(a:string, '\n\+$', '', '')
endfunction

function! s:find_repo_root()
    let metadir = s:find_metadir()
    if metadir == ''
        return ''
    else
        return fnamemodify(metadir, ':h')
    endif
endfunction

function! s:branch()
    let metadir_name = fnamemodify(s:find_metadir(), ':t')
    let branch_cmds = {
        \'.git': 'git symbolic-ref -q HEAD',
        \'.hg': 'hg branch',
    \}
    if index(keys(branch_cmds), metadir_name) == -1
        return ''
    endif

    let branch = system(branch_cmds[metadir_name])
    if v:shell_error != 0
        return ''
    endif
    " With vim 7.3 on OSX 10.7.4 system() was appending a NUL to the end.
    " Haven't figured out why yet.
    return substitute(branch, '\%x00', '', 'g')
endfunction
