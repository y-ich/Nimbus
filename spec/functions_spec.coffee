# 
# Copyright (C) 2013 ICHIKAWA, Yuji (New 3 Rs)

describe 'ancestorFolders', ->
    it 'returns [""] if path is "/"', ->
        expect(ancestorFolders '/').toEqual ['']

    it 'returns ancestor paths', ->
        expect(ancestorFolders '/a/b/c').toEqual ['', '/a', '/a/b', '/a/b/c']
