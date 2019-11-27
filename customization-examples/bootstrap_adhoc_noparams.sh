# what has been deposited with the U.S. Copyright Office.
#-------------------------------------------------------------
# This is a wrapper script to install packages via yum, and it is invoked during customizing or bootstrapping of a cluster
#Version 21st Sep

file="/tmp/bstrap_dir"
f="/tmp/bstrap_dir"
s="dos2unix"
t="remove"
u="xlwt"
i="conda"

echo "Called and before the for loop"


#while getopts ":f:s:t:u:i:" o;
for o in $f $s $t $u $i
 do
    case "${o}" in
        $f)
           echo "Inside option f"
           #Throw usage and exit if the option is not install or remove
            #f=${OPTARG}
            echo $f
            if [[ -f "$file" ]]; then
               rm -rf "$file"
            fi
            cmd=`mkdir -p $file`
            if [[ $? -ne 0 ]]; then
                echo "Exiting 1 from creating boot_strap directory"
                echo $cmd
                exit 1
            fi
            echo $cmd
            ;;
        $s)
            echo "Inside option s"
           #Throw usage and exit if the option is not install or remove
            #s=${OPTARG}
            echo  "Installing" $s
            cmd=`sudo package-admin -c install -p $s`
            if [[ $? -ne 0 ]]; then
                echo "Exiting 1 from package-admin install"
                echo $cmd
                exit 1
            fi
            echo $cmd 
            ;;
        $t)
           echo "Inside option t" 
           #Throw usage and exit if the option is not install or remove
            #t=${OPTARG}
            echo "Removing" $s
            cmd=`sudo package-admin -c remove -p $s`
            if [[ $? -ne 0 ]]; then
                echo "Exiting 1 from package-admin REMOVE"
                echo $cmd 
                exit 1
            fi 
            echo $cmd
            ;;
        $u)
           echo "Inside option u"
           #Throw usage and exit if the option is not install or remove
            #u=${OPTARG}
            echo $u 
            cmd=`pip install xlwt`
            if [[ $? -ne 0 ]]; then
                echo "Exiting 1 from pip install xlwt"
                echo $cmd
                exit 1
            fi
            echo $cmd
            ;;
        $i)
           echo "Inside option i" 
           #Throw usage and exit if the option is not install or remove
            #i=${OPTARG}
            echo $i
            cmd=`/home/common/conda/anaconda3/bin/conda install --yes zope`
            if [[ $? -ne 0 ]]; then
                echo "Exiting 1 from conda install zope"
                echo $cmd 
                exit 1
            fi
            echo $cmd     
            ;;

    esac
done
shift $((OPTIND-1))
