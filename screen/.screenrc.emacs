# from https://gist.github.com/joaopizani/2718397
# A killer GNU Screen Config

escape ^Ll

# the following two lines give a two-line status, with the current window highlighted
#hardstatus alwayslastline
#hardstatus string '%{= kG}[%{G}%H%? %1`%?%{g}][%= %{= kw}%-w%{+b yk} %n*%t%?(%u)%? %{-}%+w %=%{g}][%{B}%m/%d %{W}%C%A%{g}]'

# huge scrollback buffer
defscrollback 5000

# no welcome message
startup_message off

# mouse tracking allows to switch region focus by clicking
mousetrack on

# default windows
screen -t MAIN

# get rid of silly xoff stuff
#bind s split

# F2 macht ein "C-a F", falls nicht der ganze Platz im Window genutzt wird
bindkey "^[OQ" fit

chdir $LMMS_SRC_ROOT
