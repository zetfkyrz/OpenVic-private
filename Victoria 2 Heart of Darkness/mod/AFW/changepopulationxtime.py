from sys import stdin
from math import ceil


for line in stdin:
    file, s, xtime = line.split(':')
    xtime = float(xtime)
    with open(file,'r') as f:
        file_s = f.read()
        
        start = file_s.find(s)
        end = file_s.find("\n}", start)

        start = file_s.find("size = ", start, end)
        while start > 0:
            
            line_end = file_s.find("\n", start, end)
            n = int(file_s[start+7:line_end])
            
            n = ceil(n * xtime)
            file_s = file_s[:start+7] + str(n) + file_s[line_end:]

            end = file_s.find("\n}", start)
            start = file_s.find("size = ", start+1, end)
    with open(file,'w') as f: 
        f.write(file_s) 
    
    