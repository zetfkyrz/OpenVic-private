import glob

country = input()

prov = list(map(int,input().split()))

for i in range(len(prov)):
    files = glob.glob('./history/provinces/*/'+ str(prov[i]) + ' *')
    print(files)
    with open(files[0],'r' ) as f:
        s = f.read()
        scan = s.find("1861")
        end = s.find('}',scan)
        n = s.find("owner =",scan,end)
        if scan > 0 and n > 0:
                m = s.find("\n",n)
                s = s[:n] + "owner = " + country + "\n" + s[m:]
                n = s.find("controller =",scan)
                if n>0:
                    m = s.find("\n",n)
                    s = s[:n] + "controller = " + country + "\n" + s[m:]
                    n = s.rfind("}")
                    s = s[:n+1]
                else:
                    n = s.find("owner =",scan)
                    m = s.find("\n",n)
                    s = s[:m+1] + "controller = " + country + "\n" + s[m:]
                    n = s.rfind("}")
                    s = s[:n+1]
        else:
            n = s.find("owner =")
            m = s.find("\n",n)
            s = s[:n] + "owner = " + country + "\n" + s[m:]
            n = s.find("controller =")
            if n>0:
                 m = s.find("\n",n)
                 s = s[:n] + "controller = " + country + "\n" + s[m+1:]
                 n = s.rfind("}")
                 s = s[:n+1]
            else:
                n = s.find("owner =")
                m = s.find("\n",n)
                s = s[:m+1] + "controller = " + country + "\n" + s[m:]
                n = s.rfind("}")
                s = s[:n+1]

    with open(files[0],'w') as f: 
        f.write(s)
        
        
