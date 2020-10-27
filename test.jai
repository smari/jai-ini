#load "module.jai";

main :: () {
    myconf := ini_read_file("test.ini");
    print("Proxyport: %\n", ini_get_int(myconf, "https", "proxyport"));
}
