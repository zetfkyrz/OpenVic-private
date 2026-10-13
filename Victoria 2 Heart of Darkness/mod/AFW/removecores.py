import glob

prov = list(map(int,input().split()))

for i in range(len(prov)):
    files = glob.glob('./history/provinces/*/'+ str(prov[i]) + ' *')
    print(files)
    with open(files[0],'r' ) as f:
        s = f.read()
        scan = s.find("add_core")
        while scan > 0:
            n = s.find('\n', scan)
            if n == -1: 
                n = len(s) - 2
            s = s[:scan] + s[n+1:]
            scan = s.find("add_core")
    with open(files[0],'w') as f: 
        f.write(s) 
