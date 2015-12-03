let s:save_cpo = &cpo       
set cpo&vim

" CONSTANTS
let s:STATE_LOOP     = 1
let s:STATE_FINISH   = 2

let s:TITLE_LINE = 2
let s:HOWTO_LINE = s:TITLE_LINE + 2
let s:REMAIN_LINE = s:HOWTO_LINE + 2
let s:TIME_LINE = s:REMAIN_LINE + 1
let s:STATUS_LINE = s:TIME_LINE + 1
let s:GAME_LINE = s:STATUS_LINE + 2
let s:HIGH_SCORE_LINE = s:GAME_LINE + 7

let s:GAME_OFFSET = 3 " > 0
let s:BOARD_SIZE = 5
let s:REMAIN_DEFAULT = 20 

" cursor positions(0..4) and state(0..1)
let s:pos_x = 0
let s:pos_y = 0
let s:state_selected = 0

" record times
let s:high_score = 0
let s:record_time = 0

" remain
let s:remain = 0

" board takes value between 2 and 9
let s:field = []
" get 1 if already passed
let s:path_buffer = []

function! s:init_game() abort
  " open new buffer
  silent edit `='== =Twenty =='`
  silent normal! gg0
  silent only!
  setlocal buftype=nowrite
  setlocal noswapfile
  setlocal bufhidden=wipe
  setlocal buftype=nofile
  setlocal nonumber
  setlocal nolist
  setlocal nowrap
  setlocal nocursorline
  setlocal nocursorcolumn

  " set hilight
  syn match path_char "_[2-9]_"
  hi path_char ctermfg=black ctermbg=green guifg=black guibg=green
  syn match cur_char "\*[2-9]\*"
  hi cur_char ctermfg=black ctermbg=yellow guifg=black guibg=yellow

  " clear screen
  let ww = winwidth('.')  " window width
  let wh = winheight('.') " window height
  for i in range(1, wh)
    call setline(i, repeat(' ', ww))
  endfor
 
  "init variables
  let s:remain = s:REMAIN_DEFAULT
  let s:state_selected = 0
  let s:pos_x = s:BOARD_SIZE / 2
  let s:pos_y = s:BOARD_SIZE / 2 

  call s:Srand(localtime())
  let s:field = s:getGameBoard(s:BOARD_SIZE)
  let s:path_buffer = s:getGameBoard(s:BOARD_SIZE)
  for i in range(s:BOARD_SIZE)
    for j in range(s:BOARD_SIZE)
      let s:path_buffer[i][j] = 0
      let s:field[i][j] = s:Rand() % 8 + 2
    endfor
  endfor

  " draw text
  call setline(s:TITLE_LINE, ' *** =Twenty *** ')
  call setline(s:HOWTO_LINE, '[hjkl]: move, v: select, d: twenty')
  call setline(s:HOWTO_LINE+1, ' q: quit, r: retry')
  call s:setline_remain(s:remain)
  call s:setline_time(0)
  call s:setline_status('make just 20!')
  call setline(s:GAME_LINE,
        \      repeat(' ', s:GAME_OFFSET-1) . 
        \      repeat('===', s:BOARD_SIZE) . '==')
  call setline(s:GAME_LINE + 6,
        \      repeat(' ', s:GAME_OFFSET-1) . 
        \      repeat('===', s:BOARD_SIZE) . '==')
  call s:setline_high_score(s:high_score)
  redraw
endfunction

function! s:reset() abort
  bdelete
endfunction
             
" called when 'd' pressed
function! s:submit_and_update() abort
  let l:sum = 0
  for i in range(s:BOARD_SIZE)
    for j in range(s:BOARD_SIZE)
      if s:path_buffer[i][j] == 1
        let s:path_buffer[i][j] = 0
        let l:sum += s:field[i][j]
        let s:field[i][j] = s:Rand() % 8 + 2
      endif
    endfor
  endfor
  if l:sum == 20
    call s:setline_status('=Twenty !!!')
    let s:remain -= 1
    call s:setline_remain(s:remain)
  else
    call s:setline_status(l:sum . ' is not Twenty')
  endif
endfunction

function! s:draw_nums() abort
  let px = s:pos_x * 3 + s:GAME_OFFSET
  let py = s:GAME_LINE + 1 + s:pos_y
  for i in range(s:BOARD_SIZE)
    " draw frame and nums
    let row = s:field[i]
    call setline(i + 1 + s:GAME_LINE, 
          \ repeat(' ', s:GAME_OFFSET - 1) . '=' .
          \ join([' ', join(row,'  '), ' '], '')
          \ . '=')
  endfor
endfunction

function! s:draw_path() abort
  for y in range(s:BOARD_SIZE)
    let l:rowstr = ''
    for x in range(s:BOARD_SIZE)
      if s:path_buffer[y][x] != 0
        let l:rowstr = l:rowstr . '_' . s:field[y][x] . '_'
      else
        let l:rowstr = l:rowstr . ' ' . s:field[y][x] . ' '
      endif
    endfor
    let l:py = s:GAME_LINE + 1 + y
    let l:line = getline(l:py)
    let l:line = l:line[:(s:GAME_OFFSET-1)] . rowstr . l:line[(s:GAME_OFFSET+15):]
    call setline(l:py, l:line)
  endfor
endfunction

function! s:draw_pos() abort
  let px = s:pos_x * 3 + s:GAME_OFFSET
  let py = s:GAME_LINE + 1 + s:pos_y
  let l = getline(py)
  let l = l[:px-1] . '*' . l[px+1] . '*' . l[px+3:]
  call setline(py, l)
endfunction

function! s:move(dx,dy) abort
  if s:state_selected
    if s:check_path(s:pos_x + a:dx,s:pos_y + a:dy)
      let s:path_buffer[s:pos_y][s:pos_x] = 1
      let s:pos_x += a:dx
      let s:pos_y += a:dy
    endif
  else
    let s:pos_x += a:dx
    let s:pos_y += a:dy
  endif
endfunction

function! s:check_path(px, py) abort
  if s:path_buffer[a:py][a:px] == 0
    return 1
  else
    return 0
  endif
endfunction

function! s:loop()
  call s:init_game()
  let state = s:STATE_LOOP
  let rt = reltime()
  while 1
    " check status
    if s:remain <= 0
      let state = s:STATE_FINISH
    endif

    let c = getchar(0)
    " quit game
    if c == 27 || c == 113 " Esc, q
      return 0
    endif

    " retry game
    if c == 114 " r to retry
      call s:reset()
      return 1
    endif

    if c == 104 && s:pos_x > 0 " h
      call s:move(-1,0)
    endif

    if c == 106 && s:pos_y < s:BOARD_SIZE-1 " j
      call s:move(0,1)
    endif

    if c == 107 && s:pos_y > 0 " k
      call s:move(0,-1)
    endif

    if c == 108 && s:pos_x < s:BOARD_SIZE-1 " l
      call s:move(1,0)
    endif

    if state == s:STATE_LOOP
      if c == 118 && s:state_selected != 1 " v
        let s:state_selected = 1
      endif

      if c == 100 && s:state_selected != 0  " d
        let s:state_selected = 0
        let s:path_buffer[s:pos_y][s:pos_x] = 1
        call s:submit_and_update()
      endif
    
      let dt = str2float(reltimestr(reltime(rt))) 
      call s:setline_time(dt)
    else
      if s:high_score > dt
        let s:high_score = dt
        call s:setline_high_score(s:high_score)
      endif
    endif
    "draw cursor
    call s:draw_nums()
    call s:draw_path()
    call s:draw_pos()

    sleep 10m
    redraw
  endwhile
endfunction

"
" helper methods
"

" return 0 filled board
function! s:getGameBoard(size)
  let l:list = []
  for i in range(a:size)
    call add(l:list, 0)
  endfor
  let l:board = []
  for i in range(a:size)
    call add(l:board, deepcopy(l:list))
  endfor
  return l:board
endfunction

" rand
" let s:RAND_MAX 32767
let s:seed = 0
function! s:Srand(seed)
  let s:seed = a:seed
endfunction

function! s:Rand()
  let s:seed = s:seed * 214013 + 2531011
  return (s:seed < 0 ? s:seed - 0x80000000 : s:seed) / 0x10000 % 0x8000
endfunction

" setlines

function! s:setline_remain(remain)
  call setline(s:REMAIN_LINE, ' Remain: ' . a:remain)
endfunction

function! s:setline_time(time)
  call setline(s:TIME_LINE, ' Time  : ' . printf("%3.2f",a:time))
endfunction

function! s:setline_status(status)
  call setline(s:STATUS_LINE, ' Status: ' . a:status)
endfunction

function! s:setline_high_score(high_score)
  call setline(s:HIGH_SCORE_LINE, 
        \ ' High Score: ' . printf("%3.2f",a:high_score))
endfunction

function! s:setline_debug(data)
  call setline(s:HIGH_SCORE_LINE+2, a:data)
endfunction

function! twenty#start() abort
  let s:high_score = 9999
  while s:loop()
  endwhile
  bdelete
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
