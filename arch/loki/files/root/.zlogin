if [[ -x ~/.runonce.sh ]]
then
    rm -f ~/.running.sh
    mv ~/.runonce.sh ~/.running.sh
    ~/.running.sh
    rm -f ~/.running.sh
fi
