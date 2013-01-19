describe 'nimbus', ->
    it 'shows cover flow', ->
        waitsFor (->
                @$app = $('#iframe-app').contents()
                @$app.find('#sign-inout').text() is 'sign-out'
            ), 'can not sign-in.', 2000
        waitsFor (->
                @$coverflow = @$app.find('button[value="coverflow"]')
                @$coverflow.length == 1 and not @$coverflow.attr('disabled')?
            ), 'cover flow button is disabled.', 2000
        runs ->
            @$coverflow.click()
        waitsFor (->
                @$app.find('.coverflow-cell').length > 0
            ), 'could find cover flow', 2000
        waits 2000
        runs ->
            expect(@$app.find('.coverflow-cell')).toBeVisible()
