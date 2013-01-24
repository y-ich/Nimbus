MAX_WAIT_TIME = 2000
appReady = false
$ ->
    $('#iframe-app').on 'load', -> appReady = true

describe 'nimbus', ->
    $app = null
    $signInout = null
    isSignedIn = -> $app.find('#sign-inout').text() is 'sign-out' and not $app.find('#share').attr('disabled')?
    
    waitsFor (-> appReady), 'can not start up app.', MAX_WAIT_TIME
    runs ->
        $app = $('#iframe-app').contents()
        $signInout = $app.find('#sign-inout')
    waitsFor (-> $signInout.text() isnt 'signing-in...'), 'can not finish authentication process.', MAX_WAIT_TIME

    # no test for sign-in/out due to "Refused to display document because display forbidden by X-Frame-Options."
    ###
    describe 'sign in/out button', ->
        it 'toggles sign in state', ->
            currentState = $signInout.text()
            console.log currentState

            runs -> $signInout.click()
            waitsFor (->
                $signInout.text() is switch currentState
                    when 'sign-in' then 'sign-out'
                    when 'sign-out' then 'sign-in'
            ), 'can not toggle', MAX_WAIT_TIME_FOR_SIGNIN
            runs ->
                expect(true).toBe(true)

        it 'toggles sign in state again', ->
            currentState = $signInout.text()
            runs -> $signInout.click()
            waitsFor (->
                $signInout.text() is switch currentState
                    when 'sign-in' then 'sign-out'
                    when 'sign-out' then 'sign-in'
            ), 'can not toggle', MAX_WAIT_TIME_FOR_SIGNIN
            runs ->
                expect(true).toBe(true)
    ###
    describe 'breadcrumbs', ->
        it 'moves to home folder', ->
            runs -> $app.find('#footer a').filter((e) -> e.text() is 'Home').click()

            waitsFor (-> $app.find('#footer a').length == 1), 'can not move to Home', MAX_WAIT_TIME

            runs -> expect(true).toBe true
            
    describe 'folder in list', ->
        it 'moves to test folder', ->
            runs -> $app.find('#file-list > tbody > tr').filter((e) -> $(e).children(':last').text() is 'folder').click()

            waitsFor (-> $app.find('#footer a').length == 1), 'can not move to Home', MAX_WAIT_TIME

            runs -> expect(true).toBe true
            
    describe 'view mode buttons', ->
        it 'shows cover flow', ->
            runs -> $app.find('button[value="coverflow"]').click()

            waitsFor (->
                    $app.find('.coverflow-cell:visible').length > 0
                ), 'could find cover flow', MAX_WAIT_TIME

            runs -> expect(true).toBe true

        it 'shows file list', ->
            runs -> $app.find('button[value="list"]').click()

            waitsFor (->
                    $app.find('#file-list:visible').length > 0
                ), 'could find file list', MAX_WAIT_TIME

            runs -> expect(true).toBe true

    describe 'plus button', ->
        it 'shows dropdown menu', ->
            $dropdown = $app.find('ul:has(#menu-upload)')

            runs -> expect($dropdown.css('display')).toBe 'none'

            runs -> $dropdown.prev().click()

            waitsFor (-> $dropdown.css('display') isnt 'none'), 'can not see dropdown', MAX_WAIT_TIME
            
            runs -> expect(true).toBe true

