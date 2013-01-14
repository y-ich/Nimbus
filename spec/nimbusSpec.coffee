describe 'nimbus', ->
    describe 'sign-in, sign-out', ->
        beforeEach ->
            loadFixtures 'index.html'
        
        it 'sign-ins Dropbox', ->
            $('#sign-inout').click()
            expect