function myip
    curl -$1 ifconfig.me
    echo ""
end

function hb
    if test (count $argv) -eq 0
        echo "No file path specified."
        return
    end

    if test ! -f $argv[1]
        echo "File path does not exist."
        return
    end

    set uri "http://bin.christitus.com/documents"
    set response (curl -s -X POST -d (cat $argv[1]) $uri)

    if test $status -eq 0
        set hasteKey (echo $response | jq -r '.key')
        echo "http://bin.christitus.com/$hasteKey"
    else
        echo "Failed to upload the document."
    end
end


function tkg_update
    if test -d $HOME/.cache/linux-tkg
        sudo rm -r $HOME/.cache/linux-tkg
    end

    sleep 1
    set tkg_kernel_url "https://github.com/Frogging-Family/linux-tkg.git"

    git clone $tkg_kernel_url $HOME/.cache/(basename $tkg_kernel_url .git)
    sleep 2
    cd $HOME/.cache/linux-tkg
    makepkg -si
    #chmod +x install.sh
    #./install.sh install
    cd ..
    sudo rm -r linux-tkg
    cd
    set current_date (date +%s)
    set last_prompt_file $HOME/.config/.last_prompt_date
    sleep 1
    echo $current_date > $last_prompt_file
end

function prompt_shell
    set -l last_prompt_file "$HOME/.config/.last_prompt_date"
    set -l current_date (date +%s)
    set -l last_prompt_date 0

    # If the file exists, read the last prompt date from it
    if test -f $last_prompt_file
        set last_prompt_date (cat $last_prompt_file)
    end

    # Calculate the difference between the current date and the last prompt date
    set -l diff (math $current_date - $last_prompt_date)
    set -l two_weeks (math 7 * 24 * 3600)  # 7 days in seconds

    # If it's been more than 7 days since the last prompt, prompt the shell
    if test $diff -ge $two_weeks
        echo $current_date > $last_prompt_file
        read -P "You wanna update the TKG kernel? It's been more than a week (y/n): " response
        if test (string upper $response) = "Y"
            tkg_update
        else
            echo "No update performed."
        end
    end
end
