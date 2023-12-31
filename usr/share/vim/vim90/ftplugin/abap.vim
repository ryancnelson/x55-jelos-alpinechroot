" Vim filetype plugin file
" Language:	ABAP
" Author:	Steven Oliver <oliver.steven@gmail.com>
" Copyright:	Copyright (c) 2013 Steven Oliver
" License:	You may redistribute this under the same terms as Vim itself
" Last Change:  2023 Aug 28 by Vim Project (undo_ftplugin)
" --------------------------------------------------------------------------

" Only do this when not done yet for this buffer
if (exists("b:did_ftplugin"))
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

setlocal softtabstop=2 shiftwidth=2
setlocal suffixesadd=.abap

let b:undo_ftplugin = "setl sts< sua< sw<"

" Windows allows you to filter the open file dialog
if has("gui_win32") && !exists("b:browsefilter")
  let b:browsefilter = "ABAP Source Files (*.abap)\t*.abap\n" .
                     \ "All Files (*.*)\t*.*\n"
  let b:undo_ftplugin .= " | unlet! b:browsefilter"
endif

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: set sw=4 sts=4 et tw=80 :
