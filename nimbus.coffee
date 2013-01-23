###
# Dropbox filer by web app
(C) 2012-2013 ICHIKAWA, Yuji (New 3 Rs)
###

# global variables

DROPBOX_THUMBNAIL_DIMENSIONS =
    xs: [32, 32]
    small: [32, 32]
    s: [64, 64]
    medium: [64, 64]
    m: [128, 128]
    large: [128, 128]
    l: [640, 480]
    xl: [1024, 768]
DROPBOX_API_KEY = 'YhIlKUggAFA=|prhxrh5PMBEqJAeN5Jjox+gc9NV/zlEy2UGJTcK+4A=='
FLICKR_API_KEY = 'deab42733a35afe10cee60d4daeed7c6'
INSTAGRAM_CLIENT_ID = '04f30474ba9347eaae106a7c1c6f77dd'
MAX_NUM_SEARCH_PHOTOS = 10
instajam = null
dropbox = null
directUrl = null
currentStats = null
spinner = null
center = null
mainViewController = null
fileModalController = null
viewerController = null

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
        Math.round(n / 1000).toString() + 'KB'
    else if n < 1000000000
        Math.round(n / 1000000).toString() + 'MB'
    else if n < 1000000000000
        Math.round(n / 1000000000).toString() + 'GB'

getExtension = (path) ->
    ### returns extention in path. ###
    if /\./.test path then path.replace /^.*\./, '' else ''

isJpegFile = (name) ->
    ### judges whether JPEG or not by file name extension. ###
    ['jpg', 'jpeg', 'jpe', 'jfif', 'jfi', 'jif'].indexOf(getExtension(name).toLowerCase()) >= 0

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

obj2query = (obj) ->
    ### returns query string of obj(hash). ###
    (encodeURIComponent(key) + '=' + encodeURIComponent(value) for key, value of obj).join '&'

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
            # emacs backup file (ex .txt~) cause this for some requests.
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
            if 500 <= error.status < 600
                alert 'Sorry, there seems something wrong in Drobox server.'
                console.error 'Server error'
            else # abort etc.
                console.log 'abort?'

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

compareStatBy = (order, direction) ->
    ### returns compare function for stats by order and direction ###
    sign = if direction is 'ascending' then 1 else -1
    switch order
        when 'name'
            (a, b) -> sign * compareString a.name.toLowerCase(), b.name.toLowerCase()
        when 'kind'
            (a, b) -> sign * compareString getExtension(a.name).toLowerCase(), getExtension(b.name).toLowerCase()
        when 'date'
            (a, b) -> sign * (a.modifiedAt.getTime() - b.modifiedAt.getTime())
        when 'size'
            (a, b) -> sign * (a.size - b.size)        
        when 'place'
            (a, b) -> sign * compareString a.path.toLowerCase(), b.path.toLowerCase()

exifDate2Date = (str) ->
    ### returns JavaScript Date understandable date string from EXIF DateTime format. ###
    return null unless str?
    new Date Date.parse str.replace(/^(\d+):(\d+):(\d+)/, '$1/$2/$3') + ' UTC'

# service interfaces

flickrSearch = (param, callback) ->
    ###
    searches Flickr.
    http://www.flickr.com/services/api/flickr.photos.search.html
    ###
    defaultQuery =
        api_key: FLICKR_API_KEY
        method: 'flickr.photos.search'
        per_page: MAX_NUM_SEARCH_PHOTOS
        format: 'json'
    param[key] ?= value for key, value of defaultQuery
    $.getJSON "http://www.flickr.com/services/rest/?#{obj2query param}&jsoncallback=?", null, callback

panoramioSearch = (param, callback) ->
    defaultQuery =
        set: 'full'
        from: 0
        to: MAX_NUM_SEARCH_PHOTOS
        size: 'thumbnail'
        mapfilter: false
    param[key] ?= value for key, value of defaultQuery
    $.getJSON "http://www.panoramio.com/map/get_panoramas.php?#{obj2query param}&callback=?", null, callback

# Controllers

class PanelController
    ###
    Controller for top-level UI
    It is responsible for sign-in/out button, breadcrumbs for folder path, new folder menu, upload menu, and search.
    ###
    constructor: ->
        _self = this
        @$breadcrumbs = $('#footer .breadcrumb')

        $signInout = $('#sign-inout')
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

        @$breadcrumbs.on 'click', 'li:not(.active) > a', ->
            $this = $(this)
            $this.parent().nextUntil().remove() # removes descendent folders.
            $this.parent().addClass 'active'
            path = $this.data 'path'
            _self.getAndShowFolder path
            false

        $('#menu-new-folder').on 'click', ->
            name = prompt 'Folder Name'
            return false unless name and name isnt ''

            spinner.spin document.body
            dropbox.mkdir config.get('currentFolder') + '/' + name, (error, stat) ->
                spinner.stop()
                if error
                    handleDropboxError error
                else
                    _self.getAndShowFolder()
            false

        # upload

        $filePicker = $('#file-picker')
        $('#menu-upload').on 'click', ->
            $(this).parent().parent().prev().focus() # focus to the button.
            $filePicker.click()
            false

        $filePicker.on 'change', (event) ->
            spinner.spin document.body
            for file in @files
                dropbox.writeFile config.get('currentFolder') + '/' + file.name, file, null, (error, stat) ->
                    spinner.stop()
                    if error
                        handleDropboxError error
                    else
                        _self.getAndShowFolder()

        # search

        xhr = null
        searchString = null
        $('#search').on 'keyup', ->
            $this = $(this)
            xhr.abort() if xhr?
            xhr = null
            if $this.val() is ''
                _self.getAndShowFolder() # if search field is empty, then show current folder.
            else if $this.val() isnt searchString
                spinner.spin document.body
                searchString = $this.val()
                xhr = dropbox.findByName '', searchString, null, (error, stats) ->
                    if error
                        handleDropboxError error
                    else
                        mainViewController.updateView stats, true
                    spinner.stop()
                    xhr = null

    getAndShowFolder: (path) =>
        ### gets and shows folder content. path is a folder path. If it is not given, current folder will be shown. ###
        path ?= config.get 'currentFolder'
        spinner.spin document.body
        mainViewController.disableClick()
        dropbox.readdir path, null, (error, names, stat, stats) =>
            spinner.stop()
            if error
                handleDropboxError error
            else
                config.set 'currentFolder', path
                @_updateBreadcrumbs path
                mainViewController.updateView stats, false

    _updateBreadcrumbs: (path) ->
        ### udpates breadcrumb of folder path. ###
        @$breadcrumbs.empty()
        for e, i in ancestorFolders path
            if i == 0
                @$breadcrumbs.append '<li><a href="#" data-path="/">Home</a></li>'
            else
                name = e.replace /^.*\//, ''
                @$breadcrumbs.append """
                    <li>
                        <span class="divider">/</span>
                        <a href="#" data-path="#{e}">#{name}</a>
                    </li>
                    """
        @$breadcrumbs.children('li:last-child').addClass 'active'


class MainViewController
    ###
    is responsible for view of file list, list operations, and a button for switching view.
    public methods are,
        updateView(stats) - update view according to stats
        enableClick - enable rows and anchors to click
        disableClick - disable rows and anchors to click
    ###
    constructor: ->
        _self = this
        @stats = null
        @coverflow = null
        @$fileList = $('#file-list')
        @$tbody = @$fileList.children 'tbody'
        @$thead = @$fileList.children 'thead'
        # don't use variable of $('#coverflow'). $('#coverflow') is not static due to coverflow.js.

        @_onClickFileRow = (event) ->
            ### event handler for file list. ###
            $this =$(this)
            stat = $this.data 'dropbox-stat'
            if not stat?
                return
            if stat.isFile
                if $this.hasClass 'info'
                    _self.disableClick() # prevents malfunction due to double click
                    fileModalController.open stat
                else
                    _self.$tbody.children().removeClass 'info'
                    $this.addClass 'info'
            else if stat.isFolder
                panelController.getAndShowFolder stat.path

        @_onClickFileAnchor = (event) ->
            path = $(this).text()
            panelController.getAndShowFolder path
            event.preventDefault()
        
        if @_viewMode() is 'list'
            @$fileList.parent().css 'display', 'block'
            $('#coverflow').css 'display', 'none'
        else
            @$fileList.parent().css 'display', 'none'
            $('#coverflow').css 'display', 'block'
                
        $('#radio-view > button').on 'click', -> _self._switchView $(this).val()

        @$thead.children().on 'click', 'th:not(:first)', ->
            $this = $(this)
            orderAndDirection = 
                order: $this.children('span').text()
                direction: if $this.hasClass 'ascending' then 'descending' else 'ascending'
            config.set 'fileList', orderAndDirection
            _self._sortFileList orderAndDirection.order, orderAndDirection.direction    

        $popovered = null
        $('#share').on 'click', (event) ->
            $popovered = _self.$tbody.children 'tr.info'
            if $popovered.length == 0
                $popovered = $(this)
                $popovered.popover
                    placement: 'bottom'
                    trigger: 'manual'
                    title: 'How to share' # no title for copy & paste
                    content: 'Select a file and touch this button!'
                $popovered.popover 'show'                
            else
                stat = $popovered.data 'dropbox-stat'
                spinner.spin document.body
                dropbox.makeUrl stat.path, null, (error, url) ->
                    spinner.stop()
                    if error
                        handleDropboxError error
                        alert 'Link for sharing it is not available.' if error.status = 403
                    else
                        $popovered.popover
                            placement: 'bottom'
                            trigger: 'manual'
                            title: '' # no title for copy & paste
                            content: url.url
                        $popovered.popover 'show'
        # cancel popover for sharing
        $(document).on (if window.Touch? then 'touchstart' else 'mousedown'), (event) ->
            if $popovered? and not $(event.target).hasClass 'popover-content'
                $popovered.popover 'destroy'
                $popovered = null
                event.preventDefault()

    updateView: (@stats, search = false) ->
        if @_viewMode() is 'coverflow'
            @_drawCoverFlow()
            @_clearFileList()
        else
            @_drawFileList config.get('fileList').order, config.get('fileList').direction, search
            @_clearCoverFlow()

    enableClick: ->
        @$tbody.on 'click', 'tr', @_onClickFileRow
        @$tbody.on 'click', 'a', @_onClickFileAnchor
        
    disableClick: ->
        @$tbody.off 'click', 'tr', @_onClickFileRow
        @$tbody.off 'click', 'a', @_onClickFileAnchor

    _viewMode: -> $('#radio-view > button.active').val()
        
    _clearFileList: -> @$tbody.empty()
        
    _clearCoverFlow: ->
        @coverflow?.remove()
        @coverflow = null

    _switchView: (view) ->
        return unless @stats?
        if view is 'coverflow'
            @$fileList.parent().css 'display', 'none'
            @_drawCoverFlow() unless @_isCoverFlowUpdated()
            $('#coverflow').css 'display', 'block'
        else
            @_drawFileList config.get('fileList').order, config.get('fileList').direction unless @_isFileListUpdated()
            @$fileList.parent().css 'display', 'block'
            $('#coverflow').css 'display', 'none'

    _isFileListUpdated: -> @$tbody.children().length > 0

    _isCoverFlowUpdated: -> @coverflow?

    _drawFileList: (order, direction, search = false) ->
        ###
        prepares file list.
        if search is false, each stat in stats should be in same folder.    
        ###
        tdGenerators = [
            ['image', (stat) -> "<td><img height=\"48\" src=\"#{thumbnailUrl stat}\"></td>"]
            ['name', (stat) -> "<td>#{stat.name}</td>"]
            ['date', (stat) -> "<td>#{dateString stat.modifiedAt}</td>"]
        ]
        tdGenerators = tdGenerators.concat if search
                [['place', (stat) -> "<td><a href=\"#\">#{stat.path.replace /\/[^\/]*?$/, ''}</a></td>"]]
            else
                [
                    ['size', (stat) -> "<td style=\"text-align: right;\">#{byteString stat.size}</td>"]
                    ['kind', (stat) -> "<td>#{if stat.isFile then getExtension stat.name else 'folder'}</td>"]
                ]
        thGenerator = (key) -> "<th#{(if order is key then ' class=' + direction else '') +
            (if key is 'size' then ' style=\"text-align: right;\"' else '')}><span>#{key}</span></th>"
        @$thead.children().html tdGenerators.map((e) -> thGenerator e[0]).join ''
            
        stats = @stats.sort compareStatBy order, direction

        trs = []
        for stat in stats
            $tr = $("<tr>#{tdGenerators.map((e) -> e[1] stat).join('')}</tr>")
            $tr.data 'dropbox-stat', stat
            trs.push $tr

        @$tbody.empty()
        @$tbody.append trs
        @enableClick()

    _sortFileList: (order, direction) ->
        ### sorts file list. ###
        @_updateHeader order, direction
        $trs = @$tbody.children()
        $trs.detach()
        $trs.sort (a, b) -> compareStatBy(order, direction) $(a).data('dropbox-stat'), $(b).data('dropbox-stat')
        @$tbody.append $trs

    _updateHeader: (order, direction) ->
        @$thead.find("th.#{className}").removeClass className for className in ['ascending', 'descending']
        @$thead.find('th > span').filter(-> $(this).text() is order).parent().addClass direction

    _drawCoverFlow: ->
        ### prepares cover flow. ###
        size = 'l'
        width = 320
        stats = @stats
        if /iPhone|iPad/.test navigator.userAgent
            dimension = DROPBOX_THUMBNAIL_DIMENSIONS[size]
            max = Math.floor(5000000 / (width * width * dimension[0] / dimension[1])) # 5000000 is limit of canvas.
            if @stats.length > max
                stats = @stats[0...max]
                setTimeout (-> alert 'Too many files, trying to some of them.'), 0

        options =
            width: '100%'
            coverwidth: width
            height: $('#coverflow').parent().height() # can not use '100%'
            playlist: stats.map (stat) ->
                play = 
                    "title": stat.name
                    "description": ''
                    "image": thumbnailUrl stat, size
                    "link": null
                    "duration": ''
                    "stat": stat # extension for this app
                if stat.isFile
                    unless /~$/.test stat.name # You can not make URL for backup file (ex. .txt~). (403 forbidden)
                        dropbox.makeUrl stat.path, download: true, (error, url) ->
                            if error
                                handleDropboxError error, stat.path
                            else
                                play.link = url.url
                play
        spinner.spin document.body
        @coverflow = coverflow 'coverflow'
        @coverflow.setup(options).on 'ready', ->
            spinner.stop()
            @on 'click', (index, link) ->
                stat = @config.playlist[index].stat
                if link?
                    viewerController.preview stat, link
                else if stat.isFolder
                    panelController.getAndShowFolder stat.path

class FileModalController
    ###
    is resonsible for information modal window for each file.
    public method is
        open(stat) - opens information modal window for stat.
    ###
    constructor: ->
        @$fileModal = $('#file-modal')
        $fileModal = @$fileModal
        $('#open').on 'click', (event) ->
            stat = $('#file-list > tbody > tr.info').data 'dropbox-stat'
            viewerController.preview stat, directUrl
            $fileModal.modal 'hide'

        $('#delete').on 'click', (event) ->
            stat = $('#file-list > tbody > tr.info').data 'dropbox-stat'
            if confirm "Do you really delete #{stat.name}?"
                spinner.spin document.body
                dropbox.remove stat.path, (error, stat) ->
                    spinner.stop()
                    if error
                        handleDropboxError error
                    else
                        $fileModal.modal 'hide'
                        panelController.getAndShowFolder()

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
                        $fileModal.find('.modal-body').empty()
                        FileModalController._makeHistoryList stats

        $fileModal.on 'click', 'tbody tr', (event) ->
            $this =$(this)
            $fileModal.find('tr').removeClass 'info'
            $this.addClass 'info'
            $('#revert').removeAttr 'disabled'

        $fileModal.on 'hidden', (event) ->
            mainViewController.enableClick()

    open: (stat) ->
        $fileModal = @$fileModal
        $fileModal.find('h3').html "<img src=\"#{thumbnailUrl stat}\">#{stat.name}"
        $fileModal.find('.modal-body').empty()
        $('#open').attr 'disabled', 'disabled'
        spinner.spin document.body
        dropbox.history stat.path, null, (error, stats) ->
            spinner.stop()
            if error
                handleDropboxError error
            else
                FileModalController._makeHistoryList stats
            $fileModal.modal 'show'
        directUrl = null
        dropbox.makeUrl stat.path, download: true, (error, url) ->
            if error
                handleDropboxError error
            else
                directUrl = url.url
                $('#open').removeAttr 'disabled'

    @_makeHistoryList: (stats) ->
        ### prepares file history list. ###
        ITEMS = [
            ['date', (stat) -> "<td>#{dateString stat.modifiedAt}</td>"]
            ['size', (stat) -> "<td style=\"text-align: right;\">#{byteString stat.size}</td>"]
        ]

        $table = $('<table class="table"></table>')
    
        th = (key) -> "<th#{if key is 'size' then ' style="text-align: right;"' else ''}><span>#{key}</span></th>"
        $table.append "<thead><tr>#{ITEMS.map((e) -> th e[0]).join('')}</tr></thead>"

        stats = stats.sort (a, b) -> b.modifiedAt.getTime() - a.modifiedAt.getTime()

        $tbody = $('<tbody></tbody>')
        for stat in stats
            $tr = $("<tr>#{ITEMS.map((e) -> e[1] stat).join('')}</tr>")
            $tr.data 'dropbox-stat', stat
            $tbody.append $tr
        $table.append $tbody
    
        $('#file-modal .modal-body').append $table
        $('#revert').attr 'disabled', 'disabled' # revert button is disabled until any tr selected.

class ViewerController
    constructor: (@modalController) ->
        @$viewer = $('#viewer')
        
        $('#button-info').on 'click', (event) =>
            @modalController.show()

        $('#viewer > .close').on 'click', (event) ->
            $(this).parent().fadeOut()

    preview: (stat, link) ->
        ###
        For pictures, it shows preview and prepares information modal window.
        For others, suggests to open new browser tab or window to show.
        ### 
        @$viewer.css 'background-image', ''
        $('#button-info').attr 'disabled', 'disabled'
    
        switch getExtension(stat.name).toLowerCase()
            when 'jpg', 'jpeg', 'jpe', 'jfif', 'jfi', 'jif'
                @$viewer.css 'background-image', "url(\"#{thumbnailUrl stat, 'xl'}\")"
                @$viewer.fadeIn()
                spinner.spin $('#button-info')[0]
                xhr = dropbox.readFile stat.path, binary: true, -> spinner.stop()
                xhr.onprogress = =>
                    dirtyText = if xhr.responseText? then xhr.responseText else xhr.response
                    bytes = []
                    for i in [0...dirtyText.length]
                      bytes.push String.fromCharCode(dirtyText.charCodeAt(i) & 0xFF)
                    text = bytes.join ''
                    try
                        jpeg = new JpegMeta.JpegFile text, stat.name
                        # No error means enough to retrieve metadata.
                        xhr.abort()
                        spinner.stop()
                        @modalController.prepareViewerModal stat, jpeg.metaGroups
                        $('#button-info').removeAttr 'disabled'
                    catch error
            when 'png', 'gif'
                @$viewer.css 'background-image', "url(\"#{link}\")"
                @$viewer.fadeIn()
            else
                spinner.spin document.body
                dropbox.makeUrl stat.path, download: true, (error, url) ->
                    spinner.stop()
                    bootbox.confirm 'Do you want to open in new tab?', (result) ->
                        window.open url.url if result
                
class PhotoViewerModalController
    ###
    is resposible for viewer modal window for photos.
    public method is,
        prepareViewerModal(stat, metaGroups)
    ###
    constructor: ->
        @$viewerModal = $('#viewer-modal')
        @$photoServices = $('#photo-services')
        @$maps = $('#google-maps')
        @$metadata = $('#metadata')
        @$viewerModal.on 'shown', =>
            if @center? and @maps?
                google.maps.event.trigger @maps, 'resize' 
                @maps.setCenter @center
        
    prepareViewerModal: (stat, metaGroups) ->
        @$photoServices.empty()
        @$photoServices.prev().css 'display', 'none'
        @$viewerModal.find('h3').html "<img src=\"#{thumbnailUrl stat, 'm'}\">#{stat.name}"
        if metaGroups.gps?
            @$maps.css 'display', ''
            @center = new google.maps.LatLng metaGroups.gps.latitude.value, metaGroups.gps.longitude.value
            unless @maps?
                @maps = new google.maps.Map @$maps[0], 
                    zoom: 16
                    center: @center
                    mapTypeId: google.maps.MapTypeId.ROADMAP
            marker = new google.maps.Marker
                map: @maps
                position: @center

            @_searchPhotos @center.lat(), @center.lng(), exifDate2Date metaGroups.exif?.DateTimeOriginal?.value ? null
        else
            @center = null
            @$maps.css 'display', 'none'

        @$metadata.empty()
        for key, value of metaGroups
            for k, v of value when v instanceof JpegMeta.MetaProp
                @$metadata.append "<dt>#{v.description}</dt>"
                @$metadata.append "<dd>#{v.value}</dd>"

    show: -> @$viewerModal.modal 'show'

    _searchPhotos: (lat, lng) -> # limiting by date if currently disabled.
        flickrSearch
                ###
                min_taken_date: Math.floor new Date(date.getFullYear(), date.getMonth(), date.getDate(), 0, 0, 0, 0) / 1000
                max_taken_date: Math.floor new Date(date.getFullYear(), date.getMonth(), date.getDate(), 23, 59, 59, 99) / 1000
                ###
                has_geo: 1
                lat: lat
                lon: lng
                radius: 5
            , (data) =>
                return if data.stat is 'fail'
                photos = data.photos.photo
                if photos.length > 0
                    @$photoServices.prev().css 'display', 'block'
                    for i in [0...photos.length]
                        @$photoServices.append "<img src=\"http://static.flickr.com/#{photos[i].server}/#{photos[i].id}_#{photos[i].secret}_s.jpg\">"

        earthRadius = 6378.137 # km
        range = 5 # km
        rangeRadian = range / earthRadius
        lngRangeRadian = rangeRadian / Math.cos(lat * Math.PI / 180)
        panoramioSearch
                minx: lng - lngRangeRadian
                maxx: lng + lngRangeRadian
                miny: lat - rangeRadian
                maxy: lat + rangeRadian
            , (data) =>
                photos = data.photos
                if photos.length > 0
                    @$photoServices.prev().css 'display', 'block'
                    for i in [0...photos.length]
                        @$photoServices.append "<img src=\"#{photos[i].photo_file_url}\">"
        instajam.media.search
                lat: lat
                lng: lng
            , (result) => 
                if result instanceof Error
                    console.error result
                else
                    if result.data.length > 0
                        @$photoServices.prev().css 'display', 'block'
                        @$photoServices.append "<img src=\"#{e.images.thumbnail.url}\">" for e in result.data[0...MAX_NUM_SEARCH_PHOTOS]

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
        localStorage[@key] = JSON.stringify @object

initializeDropbox = ->
    ###
    1. check forwarded result.
    2. disable Dropbox related buttons.
    3. prepares Dropbox Client instance.
    4. if not approved, a user rejected authentication request. Does nothing.
    5. checks localStorage. if it includes data for this APP_KEY, tries to sign in. 
    ###
    notApproved = /not_approved=true/.test location.toString()
    $signInout = $('#sign-inout')

    $('#header button:not(#sign-inout)').attr 'disabled', 'disabled'
    dropbox = new Dropbox.Client
        key: DROPBOX_API_KEY
        sandbox: false
    dropbox.authDriver new Dropbox.Drivers.Redirect rememberUser: true
    
    return if notApproved

    try
        for key, value of localStorage when /^dropbox-auth/.test(key) and JSON.parse(value).key is dropbox.oauth.key
            $signInout.button 'loading'
            $signInout.removeClass 'btn-primary'
            dropbox.authenticate (error, client) ->
                if error
                    handleDropboxError error 
                    $signInout.button 'reset'
                    $signInout.addClass 'btn-primary'
                else
                    $signInout.button 'signout'
                    $('#header button:not(#sign-inout)').removeAttr 'disabled'
                    panelController.getAndShowFolder()
            break
    catch error
        console.log error

    window.history.replaceState null, null, location.pathname # clear forwarded query parameter


# main
unless jasmine?
    new NoClickDelay document.body, ['BUTTON', 'A', 'INPUT', 'TH', 'TR']
    spinner = new Spinner()
    panelController = new PanelController()
    mainViewController = new MainViewController()
    fileModalController = new FileModalController()
    viewerController = new ViewerController new PhotoViewerModalController()
    instajam = new Instajam client_id: INSTAGRAM_CLIENT_ID
    config = PersistentObject.restore 'nimbus-config',
        currentFolder: '/'
        fileList:
            order: 'name'
            direction: 'ascending'
    initializeDropbox()
