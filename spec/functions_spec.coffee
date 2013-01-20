# 
# Copyright (C) 2013 ICHIKAWA, Yuji (New 3 Rs)

describe 'compareString', ->
    it 'returns plus if str1 is older than str2', ->
        expect(compareString 'b', 'a').toBeGreaterThan 0
        
    it 'returns minus if str1 is younger than str2', ->
        expect(compareString 'c', 'd').toBeLessThan 0

    it 'returns 0 if str1 is equal to str2', ->
        expect(compareString 'e', 'e').toBe 0

describe 'dateString', ->
    it 'returns formated date string', ->
        expect(dateString new Date(2013, 0, 18, 15, 53, 51)).toEqual 'Jan 18 2013 15:53:51 (JST)'

describe 'ByteString', ->
    it 'returns formated byte string', ->
        expect(byteString 0).toEqual '0B'

    it 'returns formated byte string', ->
        expect(byteString 1400).toEqual '1KB'

    it 'returns formated byte string', ->
        expect(byteString 2500000).toEqual '3MB'

    it 'returns formated byte string', ->
        expect(byteString 4000000000).toEqual '4GB'

describe 'getExtension', ->
    it 'returns extension', ->
        expect(getExtension 'image.jpg').toEqual 'jpg'

describe 'isJpegFile', ->
    it 'returns true if extension shows jpeg', ->
        expect(isJpegFile 'image.jpg').toBe true

    it 'returns false unless extension shows jpeg', ->
        expect(isJpegFile 'image.gif').toBe false

describe 'ancestorFolders', ->
    it 'returns [""] if path is "/"', ->
        expect(ancestorFolders '/').toEqual ['']

    it 'returns ancestor paths', ->
        expect(ancestorFolders '/a/b/c').toEqual ['', '/a', '/a/b', '/a/b/c']
