import glob
country = input()

prov = list(map(int,input().split()))

for i in range(len(prov)):
    files = glob.glob('./history/provinces/*/'+ str(prov[i]) + ' *')
    print(files)
    with open(files[0],'r' ) as f:
        s = f.read()
        scan = s.find("1861")
        if scan>0:
            n = s.find("1861.1.1 = {",scan)
            m = s.find("\n",n)
            s = s[:m+1] + "add_core = " + country + "\n" + s[m+1:]  
            n = s.rfind("}")
            s = s[:n+1]
        else:
            n = s.find("controller =")
            m = s.find("\n",n)
            s = s[:m+1] + "add_core = " + country + s[m+1:] 
            
    with open(files[0],'w') as f: 
        f.write(s) 
