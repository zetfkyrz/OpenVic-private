
xtime=$1

while [ -n "$2" ]
do

echo "$(grep -r -w "$2 = {" "./history/pops/1836.1.1/"):$1" | python3 ./changepopulationxtime.py

shift
done