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
            a = s.find("}",scan)
            n = s.find("owner =",scan,a)
            if n>0:
                m = s.find("\n",n)
                s = s[:n] + "\n"  + "owner = " + country + "\n" + s[m:]
                n = s.find("controller =",scan,a)
                if n>0:
                    a = s.find("}",scan,a)
                    m = s.find("\n",n)
                    s = s[:n] + "controller = " + country + "\n" + s[m:]
                    n = s.find("controller =",scan,a)
                    m = s.find("\n",n)
                    s = s[:m+1] + "add_core = " + country + s[m+1:] 
                    n = s.rfind("}")
                    s = s[:n+1]
                else:
                    n = s.find("owner =",scan,a)
                    m = s.find("\n",n)
                    s = s[:m+1] + "controller = " + country + "\n" + s[m:]
                    n = s.find("controller =",scan,a)
                    m = s.find("\n",n)
                    s = s[:m+1] + "add_core = " + country + s[m+1:] 
                    n = s.rfind("}")
                    s = s[:n+1]
                
            else:
                a = s.find("}",scan)
                n = s.find("1861.1.1 = {")
                m = s.find("\n",n)
                s = s[:n+1] + "\n" + "owner = " + country + "\n" + s[m+1:]
                n = s.find("controller =",scan,a)
                if n>0:
                    m = s.find("\n",n)
                    s = s[:n] + "controller = " + country + "\n" + s[m:]
                    n = s.find("controller =",scan,a)
                    m = s.find("\n",n)
                    s = s[:m+1] + "add_core = " + country + s[m+1:] 
                    n = s.rfind("}")
                    s = s[:n+1]
                else:
                    n = s.find("owner =",scan,a)
                    m = s.find("\n",n)
                    s = s[:m+1] + "controller = " + country + "\n" + s[m:]
                    n = s.find("controller =",scan,a)
                    m = s.find("\n",n)
                    s = s[:m+1] + "add_core = " + country + s[m+1:] 
                    n = s.rfind("}")
                    s = s[:n+1]
        else:
            n = s.find("owner =")
            m = s.find("\n",n)
            s = s[:n] + "owner = " + country + "\n" + s[m:]
            n = s.find("controller =")
            if n>0:
                m = s.find("\n",n)
                s = s[:n] + "controller = " + country + "\n" + s[m:]
                n = s.find("controller =")
                m = s.find("\n",n)
                s = s[:m+1] + "add_core = " + country + s[m+1:] 
                n = s.rfind("}")
                s = s[:n+1]
            else:
                n = s.find("owner =")
                m = s.find("\n",n)
                s = s[:m+1] + "controller = " + country + "\n" + s[m:]
                n = s.find("controller =")
                m = s.find("\n",n)
                s = s[:m+1] + "add_core = " + country + s[m+1:] 
                n = s.rfind("}")
                s = s[:n+1]
                

    with open(files[0],'w') as f: 
        f.write(s)
        
        
