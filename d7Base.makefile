core = 7.x
api = 2
projects[drupal][version] = 7.x

; MODULES
; --------

; Backoffice --
projects[admin_menu][type] = "module"
projects[module_filter][type] = "module"
projects[devel][type] = "module"
projects[ckeditor][type] = "module"
projects[ckeditor_link][type] = "module"
projects[imce][type] = "module"
projects[media][type] = "module"

; Performance --
projects[varnish][type] = "module"
projects[memcache][type] = "module"

; Fields --
projects[email][type] = "module"
projects[link][type] = "module"
projects[cck][type] = "module"
projects[date][type] = "module"

; Forms --
projects[honeypot][type] = "module"
projects[webform][type] = "module"

; SEO --
projects[xmlsitemap][type] = "module"

; URL Rewriting --
projects[pathauto][type] = "module"
projects[pathologic][type] = "module"

; Miscellaneous --
projects[ctools][type] = "module"
projects[token][type] = "module"
projects[transliteration][type] = "module"
projects[views][type] = "module"
projects[l10n_update][type] = "module"
projects[colorbox][type] = "module"


; LIBRARIES
; ----------

; Colorbox --
libraries[colorbox][download][type] = "get"
libraries[colorbox][download][url] = "http://github.com/jackmoore/colorbox/archive/master.zip"
libraries[colorbox][type] = "library"
libraries[colorbox][directory_name] = "colorbox"


; THEMES
; ----------

; Front --
projects[basic-d7-cua][download][url] = "https://bitbucket.org/commeunarbre/basic-d7-cua/get/HEAD.zip"
projects[basic-d7-cua][download][type] = "get"
projects[basic-d7-cua][type] = "theme"

; Back --
projects[tao][type] = "theme"
projects[rubik][type] = "theme"
