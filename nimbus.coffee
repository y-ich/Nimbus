###
# Controller for dropbox-js
# dependencies: dropbox-js.js, jquery.js, spin.js
# usage:
#  1. prepare view (button for sign-in and sign-out, table for file list)
# (C) 2012-2013 ICHIKAWA, Yuji (New 3 Rs)
###

# global variables

API_KEY = 'YhIlKUggAFA=|prhxrh5PMBEqJAeN5Jjox+gc9NV/zlEy2UGJTcK+4A=='
dropbox = null
directUrl = null
currentStats = null
config = null
spinner = null
maps = null
center = null

# view
$signInout = null
$main = null
$breadcrumbs = null
$fileModal = null
$viewer = null
$viewerModal = null

# general functions

compareString = (str1, str2) ->
    ###
    returns 1, 0, -1 according to the order of str1 and str2.
    It is for Array#sort method.
    ###
    if str1 > str2
        1
    else if str1 < str2
        -1
    else
        0

dateString = (date) ->
    ###
    returns formated string of date.
    example: Jan 18 2013 15:53:51 (JST)
    ###
    date.toString().replace /^.*? |GMT.* /g, ''

byteString = (n) ->
    ###
    returns formated string of number as bytes.
    ###
    if n < 1000
        n.toString() + 'B'
    else if n < 1000000
        Math.floor(n / 1000).toString() + 'KB'
    else if n < 1000000000
        Math.floor(n / 1000000).toString() + 'MB'
    else if n < 1000000000000
        Math.floor(n / 1000000000).toString() + 'GB'

getExtension = (path) ->
    ### returns extention in path. ###
    if /\./.test path then path.replace /^.*\./, '' else ''

isJpegFile = (name) ->
    ### judges whether JPEG or not by file name extension. ###
    ['jpg', 'jpeg'].indexOf(getExtension(name).toLowerCase()) >= 0

ancestorFolders = (path) ->
    ###
    returns an array with ancestor folders of path.
    examples:
        '/' => ['']
        '/a/b/c' => ['', '/a', '/a/b', '/a/b/c']
    ###
    if path is '/'
        [''] 
    else
        split = path.split '/'
        split[0..i].join '/' for e, i in split

# utility functions for Dropbox

handleDropboxError = (error, path = null) ->
    ### notifies Dropbox error to user. ###
    console.log path if path?
    console.error error if (window.console)
    switch error.status
        when 400
            alert 'Sorry, there seems something wrong in software.'
            console.error 'Bad input parameter'
        when 401
            alert 'Authentication is expired. Please sign-in again.'
            $signInout.button 'reset'
        when 403
            alert 'Sorry, there seems something wrong in software.'
            console.error 'Bad OAuth request'
        when 404
            alert 'Sorry, there seems something wrong in software.'
            console.error 'No such file or folder.'
        when 405
            alert 'Sorry, there seems something wrong in software.'
            console.error 'Request method not expected.'
        when 507
            alert 'Your Dropbox seems full.'
        when 503
            alert 'Dropbox seems busy. Please try again later.'
        else
            alert 'Sorry, there seems something wrong in software.'
            if 500 <= error.status > 600
                console.error 'Server error'
            else
                console.error 'unknown error'

typeIcon48 = (typeIcon) ->
    ### returns a name of icon for 48px. ###
    switch typeIcon
        when 'page_white_excel' then 'excel48'
        when 'page_white_film' then 'page_white_dvd'
        when 'page_white_powerpoint' then 'powerpoint48'
        when 'page_white_word' then 'word48'
        when 'page_white_sound' then 'music48'
        when 'page_white_compressed' then 'page_white_zip48'
        else typeIcon + '48'

thumbnailUrl = (stat, size = 'small') ->
    ### returns thumbnail URL or 48x48 icon URL if no thumbnail. ###
    if stat.hasThumbnail
        dropbox.thumbnailUrl stat.path,
            png: not isJpegFile stat.name
            size: size
    else
        "images/dropbox-api-icons/48x48/#{typeIcon48 stat.typeIcon}.gif"

# utility classes for app

class PersistentObject
    @restore: (key, defaultValue = {}) ->
        restored = JSON.parse localStorage[key] ? '{}'
        for k, v of defaultValue
            restored[k] ?= v
        new PersistentObject key, restored

    constructor: (@key, @object) ->
        localStorage[@key] = JSON.stringify @object

    get: (key) -> @object[key]

    set: (key, value) ->
        @object[key] = value
        console.log JSON.stringify @object
        console.log @key
        localStorage[@key] = JSON.stringify @object

# DOM manupulations

prepareViewModal = (name, metaGroups) ->
    $viewerModal.find('h3').text name
    if metaGroups.gps?
        $('#google-maps').css 'display', ''
        center = new google.maps.LatLng metaGroups.gps.latitude.value, metaGroups.gps.longitude.value
        if maps?
            maps.setCenter center
        else
            maps = new google.maps.Map $('#google-maps')[0], 
                zoom: 8
                center: center
                mapTypeId: google.maps.MapTypeId.ROADMAP
            marker = new google.maps.Marker
                map: maps
                position: center
    else
        $('#google-maps').css 'display', 'none'
    $dl = $viewerModal.find('dl')
    $dl.children().remove()
    for key, value of metaGroups
        for k, v of value when v instanceof JpegMeta.MetaProp
            $dl.append "<dt>#{v.description}</dt>"
            $dl.append "<dd>#{v.value}</dd>"
    
preview = (stat, link) ->
    ### prepares contents of $('#viewer') and $('#viewerModal') and show $('#viewer'). ### 
    $viewer.css 'background-image', ''
    
    switch getExtension(stat.name).toLowerCase()
        when 'jpg', 'jpeg'
            spinner.spin document.body
            dropbox.readFile stat.path, binary: true, (error, string, stat) ->
                spinner.stop()
                $viewer.css 'background-image', "url(\"data:image/jpeg;base64,#{btoa string}\")"
                jpeg = new JpegMeta.JpegFile string, stat.name
                prepareViewModal stat.name, jpeg.metaGroups
                $('#button-info').css 'dispay', ''
                $viewer.fadeIn()
        when 'png', 'gif'
            $viewer.css 'background-image', "url(\"#{link}\")"
            $('#button-info').css 'dispay', 'none'
            $viewer.fadeIn()
        else
            null

makeFileList = (stats, order, direction) ->
    ### prepares file list. ###
    ITEMS =
        image: (stat) -> "<td><img src=\"#{thumbnailUrl stat}\"></td>"
        name: (stat) -> "<td>#{stat.name}</td>"
        date: (stat) -> "<td>#{dateString stat.modifiedAt}</td>"
        size: (stat) -> "<td style=\"text-align: right;\">#{byteString stat.size}</td>"
        kind: (stat) -> "<td>#{if stat.isFile then getExtension stat.name else 'folder'}</td>"

    $div = $('<div class="touch-scrolling"><table class="table"></table></div>')
    $table = $div.children()
    
    th = (key) -> "<th#{if order is key then " class=\"#{direction}\"" else ''}#{if key is 'size' then ' style=\"text-align: right;\"' else ''}><span>#{key}</span></th>"
    $table.append "<tr>#{Object.keys(ITEMS).map(th).join('')}</tr>"
            
    sign = if direction is 'ascending' then 1 else -1
    sortFunc = switch order
            when 'name'
                (a, b) -> sign * compareString a.name.toLowerCase(), b.name.toLowerCase()
            when 'kind'
                (a, b) -> sign * compareString getExtension(a.name).toLowerCase(), getExtension(b.name).toLowerCase()
            when 'date'
                (a, b) -> sign * (a.modifiedAt.getTime() - b.modifiedAt.getTime())
            when 'size'
                (a, b) -> sign * (a.size - b.size)        
    stats = stats.sort sortFunc

    for stat in stats
        $tr = $("<tr>#{(value(stat) for key, value of ITEMS).join('')}</tr>")
        $tr.data 'dropbox-stat', stat
        $table.append $tr

    $main.children().remove()
    $main.append $div
    $table.on 'click', 'tr', onClickFileRow # enable to click.

makeCoverFlow = (stats) ->
    ### prepares cover flow. ###
    $main.children().remove()
    $main.append '<div id="coverflow"></div>'
    options =
        width: '100%'
        coverwidth: 320
        height: $main.height()
        playlist: stats.map (stat) ->
            play = 
                "title": stat.name
                "description": ''
                "image": thumbnailUrl stat, 'l'
                "link": null
                "duration": ''
                "stat": stat
            if stat.isFile
                unless /~$/.test stat.name # You can not make URL for backup file (ex. .txt~). (403 forbidden)
                    dropbox.makeUrl stat.path, download: true, (error, url) ->
                        if error
                            handleDropboxError error, stat.path
                        else
                            play.link = url.url
            play
    coverflow('coverflow').setup(options).on 'ready', ->
        @on 'click', (index, link) ->
            preview @config.playlist[index].stat, link if link?

showFolder = (stats) ->
    ### prepares file list or cover flow. ###
    if $('#radio-view > button.active').val() is 'coverflow'
        makeCoverFlow stats
    else
        makeFileList stats, config.get('fileList').order, config.get('fileList').direction
    
getAndShowFolder = (path = '/') ->
    ### gets and shows folder content. ###
    spinner.spin document.body
    dropbox.readdir path, null, (error, names, stat, stats) ->
        spinner.stop()
        if error
            handleDropboxError error
        else
            updateBreadcrumbs path
            currentStats = stats
            showFolder stats

makeHistoryList = (stats) ->
    ### prepares file history list. ###
    ITEMS =
        date: (stat) -> "<td>#{dateString stat.modifiedAt}</td>"
        size: (stat) -> "<td style=\"text-align: right;\">#{byteString stat.size}</td>"

    $div = $('<div class="touch-scrolling"><table class="table"></table></div>')
    $table = $div.children()
    
    th = (key) -> "<th><span>#{key}</span></th>"
    $table.append "<tr>#{Object.keys(ITEMS).map(th).join('')}</tr>"
            
    stats = stats.sort (a, b) -> b.modifiedAt.getTime() - a.modifiedAt.getTime()

    for stat in stats
        $tr = $("<tr>#{(value(stat) for key, value of ITEMS).join('')}</tr>")
        $tr.data 'dropbox-stat', stat
        $table.append $tr

    $modalBody = $fileModal.find('.modal-body')
    $modalBody.append $div

updateBreadcrumbs = (path) ->
    ### udpates breadcrumb of folder path. ###
    $breadcrumbs.children().remove()
    for e, i in ancestorFolders path
        if i == 0
            $breadcrumbs.append '<li><a href="#" data-path="/">Home</a></li>'
        else
            name = e.replace /^.*\//, ''
            $breadcrumbs.append """
                <li>
                    <span class="divider">/</span>
                    <a href="#" data-path="#{e}">#{name}</a>
                </li>
                """
    $breadcrumbs.children('li:last-child').addClass 'active'

initializeDropbox = ->
    ###
    0. disable Dropbox related buttons.
    1. prepares Dropbox Client instance.
    2. checks URL. if it includes not_approved=true, a user rejected authentication request. Does nothing.
    3. checks localStorage. if it includes data for this APP_KEY, tries to sign in. 
    ###
    $('#header button:not(#sign-inout)').attr 'disabled', 'disabled'
    dropbox = new Dropbox.Client
        key: API_KEY
        sandbox: false
    dropbox.authDriver new Dropbox.Drivers.Redirect rememberUser: true
    
    return if /not_approved=true/.test location.toString() # if redirect result shows that a user rejected

    try
        for key, value of localStorage when /^dropbox-auth/.test(key) and JSON.parse(value).key is dropbox.oauth.key
            $signInout.button 'loading'
            dropbox.authenticate (error, client) ->
                if error
                    handleDropboxError error 
                    $signInout.button 'reset'
                else
                    $signInout.button 'signout'
                    $('#header button:not(#sign-inout)').removeAttr 'disabled'
                    getAndShowFolder config.get 'currentFolder'
            break
    catch error
        console.log error

onClickFileRow = (event) ->
    ### event handler for file list. ###
    $this =$(this)
    stat = $this.data('dropbox-stat')
    if not stat?
        return
    if stat.isFile
        if $this.hasClass 'info'
            $fileModal.find('h3').html "<img src=\"#{thumbnailUrl stat}\">#{stat.name}"
            $fileModal.find('.modal-body').children().remove()
            $fileModal.modal()
            spinner.spin document.body
            dropbox.history stat.path, null, (error, stats) ->
                spinner.stop()
                makeHistoryList stats
            directUrl = null
            dropbox.makeUrl stat.path, download: true, (error, url) ->
                directUrl = url.url
        else
            $main.find('tr').removeClass 'info'
            $this.addClass 'info'
    else if stat.isFolder
        $main.find('table').off 'click', 'tr', onClickFileRow # disable during updating.
        getAndShowFolder stat.path
        config.set 'currentFolder', stat.path

initializeEventHandlers = ->
    ### sets event handlers ###
    # dropbox sign in button
    $signInout.on 'click', ->
        spinner.spin document.body
        if $signInout.text() is 'sign-in'
            $signInout.button 'loading'
            dropbox.reset()
            dropbox.authenticate (error, client) ->
                spinner.stop()
                if error
                    handleDropboxError error
                else
                    $signInout.button 'signout'
                    $('#header button:not(#sign-inout)').removeAttr 'disabled'
        else
            dropbox.signOut (error) ->
                spinner.stop()
                if error
                    handleDropboxError error
                else
                    $signInout.button 'reset'
                    $('#header button:not(#sign-inout)').attr 'disabled', 'disabled'

    $('#radio-view > button').on 'click', ->
        # execute showFolder after radio button processing.
        setTimeout (-> showFolder currentStats), 0 if currentStats? # currentStats may be null in early stage.

    $breadcrumbs.on 'click', 'li:not(.active) > a', (event) ->
        event.preventDefault()
        $this = $(this)
        $this.parent().nextUntil().remove() # removes descendent folders.
        $this.parent().addClass 'active'
        path = $this.data 'path'
        getAndShowFolder path
        config.set 'currentFolder', path
    
    $main.on 'click', 'tr:first > th:not(:first)', ->
        $this = $(this)
        orderAndDirection = 
            order: $this.children('span').text()
            direction: if $this.hasClass 'ascending' then 'descending' else 'ascending'
        config.set 'fileList', orderAndDirection            
        makeFileList currentStats, orderAndDirection.order, orderAndDirection.direction
    
    $('#menu-new-folder').on 'click', (event) ->
        event.preventDefault()
        name = prompt 'Folder Name'
        return unless name and name isnt ''

        spinner.spin document.body
        dropbox.mkdir config.get('currentFolder') + '/' + name, (error, stat) ->
            spinner.stop()
            if error
                handleDropboxError error
            else
                getAndShowFolder config.get 'currentFolder'

    $('#menu-upload').on 'click', (event) ->
        event.preventDefault()
        $('#file-picker').click()

    $('#file-picker').on 'change', (event) ->
        file = event.target.files[0]
        spinner.spin document.body
        dropbox.writeFile config.get('currentFolder') + '/' + file.name, file, null, (error, stat) ->
            spinner.stop()
            if error
                handleDropboxError error
            else
                getAndShowFolder config.get 'currentFolder'

    $('#share').on 'click', (event) ->
        $active = $main.find 'tr.info'
        return if $active.length == 0
        stat = $active.data 'dropbox-stat'
        spinner.spin document.body
        dropbox.makeUrl stat.path, null, (error, url) ->
            spinner.stop()
            if error
                handleDropboxError error
            else
                $active.popover
                    placement: 'top'
                    trigger: 'manual'
                    title: 'Public URL'
                    content: url.url
                $active.popover 'show'
                $content = $active.next().find('.popover-content')
                range = document.createRange()
                range.selectNodeContents $content[0]
                sel = getSelection()
                sel.removeAllRanges()
                sel.addRange range

    $('#open').on 'click', (event) ->
        $active = $main.find 'tr.info'
        stat = $active.data 'dropbox-stat'
        preview stat, directUrl
        $fileModal.modal 'hide'

    $('#delete').on 'click', (event) ->
        $active = $main.find 'tr.info'
        stat = $active.data 'dropbox-stat'
        if confirm "Do you really delete #{stat.name}?"
            spinner.spin document.body
            dropbox.remove stat.path, (error, stat) ->
                spinner.stop()
                if error
                    handleDropboxError error
                else
                    $fileModal.modal 'hide'
                    getAndShowFolder config.get 'currentFolder'

    $fileModal.on 'click', 'tr:gt(1)', (event) ->
        $this =$(this)
        $fileModal.find('tr').removeClass 'info'
        $this.addClass 'info'

    $('#revert').on 'click', (event) ->
        $active = $fileModal.find('tr.info')
        if $active.length == 0
            alert 'select a previous version'
            return
        stat = $active.data 'dropbox-stat'
        spinner.spin document.body
        dropbox.revertFile stat.path, stat.versionTag, (error, stat) ->
            spinner.stop()
            if error
                handleDropboxError error
            else
                spinner.spin document.body
                dropbox.history stat.path, null, (error, stats) ->
                    spinner.stop()
                    $fileModal.find('.modal-body').children().remove()
                    makeHistoryList stats

    $('#button-info').on 'click', (event) ->
        event.stopPropagation() # prevent to click $viewer.
        $viewerModal.modal 'show'

    $viewer.on 'click', (event) ->
        $viewer.fadeOut()

    $viewerModal.on 'shown', ->
        if maps?
            google.maps.event.trigger maps, 'resize' 
            maps.setCenter center

# main
unless jasmine?
    NoClickDelay document.body
    spinner = new Spinner()
    $signInout = $('#sign-inout')
    $main = $('#main')
    $breadcrumbs = $('#footer .breadcrumb')
    $fileModal = $('#file-modal')
    $viewer = $('#viewer')
    $viewerModal = $('#viewer-modal')

    config = PersistentObject.restore 'nimbus-config',
        currentFolder: '/'
        fileList:
            order: 'name'
            direction: 'ascending'
    initializeDropbox()
    initializeEventHandlers()
