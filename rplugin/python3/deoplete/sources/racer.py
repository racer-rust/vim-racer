#=============================================================================
# FILE: racer.py
# AUTHOR:  Shougo Matsushita <Shougo.Matsu at gmail.com>
# License: MIT license  {{{
#     Permission is hereby granted, free of charge, to any person obtaining
#     a copy of this software and associated documentation files (the
#     "Software"), to deal in the Software without restriction, including
#     without limitation the rights to use, copy, modify, merge, publish,
#     distribute, sublicense, and/or sell copies of the Software, and to
#     permit persons to whom the Software is furnished to do so, subject to
#     the following conditions:
#
#     The above copyright notice and this permission notice shall be included
#     in all copies or substantial portions of the Software.
#
#     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
#     OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
#     MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
#     IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
#     CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
#     TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
#     SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
# }}}
#=============================================================================

import re
import os
import subprocess
import tempfile
from .base import Base

class Source(Base):
    def __init__(self, vim):
        Base.__init__(self, vim)

        self.name = 'racer'
        self.mark = '[racer]'
        self.filetypes = ['rust']
        self.input_pattern = r'(\.|::)\w*'
        self.rank = 500

    def on_init(self, context):
        self.__racer = self.vim.call('racer#GetRacerCmd')
        self.__executable_racer = self.vim.funcs.executable(self.__racer)

    def get_complete_position(self, context):
        if not self.__executable_racer:
            return -1

        m = re.search('\w*$', context['input'])
        return m.start() if m else -1


    def gather_candidates(self, context):
        typeMap = {
            'Struct': 's', 'Module': 'M', 'Function': 'f',
            'Crate': 'C',  'Let': 'v',    'StructField': 'm',
            'Impl': 'i',   'Enum': 'e',   'EnumVariant': 'E',
            'Type': 't',   'FnArg': 'v',  'Trait': 'T',
            'Const': 'c'
        }

        candidates = []
        insert_paren = int(self.vim.eval('g:racer_insert_paren'))
        for line in [l[6:] for l
                     in self.get_results(context, 'complete',
                                         context['complete_position'] + 1)
                     if l.startswith('MATCH')]:
            completions = line.split(',')
            kind = typeMap.get(completions[4], '')
            completion = { 'kind': kind, 'word': completions[0] }
            if kind == 'f': # function
                completion['menu'] = ','.join(completions[5:]).replace(
                    'pub ', '').replace('fn ', '').rstrip('{')
                if ' where ' in completion['menu'] or completion[
                        'menu'].endswith(' where') :
                    where = completion['menu'].rindex(' where')
                    completion['menu'] = completion['menu'][: where]
                if insert_paren:
                    completion['abbr'] = completions[0]
                    completion['word'] += '('
            elif kind == 's' : # struct
                completion['menu'] = ','.join(completions[5:]).replace(
                    'pub ', '').replace( 'struct ', '').rstrip('{')
            candidates.append(completion)
        return candidates

    def get_results(self, context, command, col):
        with tempfile.NamedTemporaryFile(mode='w', encoding='utf-8') as tf:
            tf.write("\n".join(self.vim.current.buffer))
            tf.flush()

            args = [
                self.__racer, command,
                str(self.vim.funcs.line('.')),
                str(col - 1),
                tf.name
            ] if command == 'prefix' else [
                self.__racer, command,
                str(self.vim.funcs.line('.')),
                str(col - 1),
                self.vim.current.buffer.name,
                tf.name
            ]
            try:
                results = subprocess.check_output(args).decode(
                    context['encoding']).splitlines()
            except subprocess.CalledProcessError:
                return []
            return results
