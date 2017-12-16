webpage=( http://bcc.suprnova.cc/index.php?page=gettingstarted
http://btg.suprnova.cc/index.php?page=gettingstarted
http://vtc.suprnova.cc/index.php?page=gettingstarted
http://poly.suprnova.cc/index.php?page=gettingstarted
http://etn.sup.rnova.cc/index.php?page=gettingstarted
http://stak.suprnova.cc/index.php?page=gettingstarted
http://smart.suprnova.cc/index.php?page=gettingstarted
http://mnx.suprnova.cc/index.php?page=gettingstarted
http://zcl.suprnova.cc/index.php?page=gettingstarted
https://zen.suprnova.cc/index.php?page=gettingstarted
http://zec.suprnova.cc/index.php?page=gettingstarted
http://btcz.suprnova.cc/index.php?page=gettingstarted
http://xzc.suprnova.cc/index.php?page=gettingstarted
http://bsd.suprnova.cc/index.php?page=gettingstarted
http://btx.suprnova.cc/index.php?page=gettingstarted
http://mac.suprnova.cc/index.php?page=gettingstarted
http://emc2.suprnova.cc/index.php?page=gettingstarted
http://kmd.suprnova.cc/index.php?page=gettingstarted
http://zdash.suprnova.cc/index.php?page=gettingstarted
http://dash.suprnova.cc/index.php?page=gettingstarted
http://zero.suprnova.cc/index.php?page=gettingstarted
http://lbry.suprnova.cc/index.php?page=gettingstarted
http://eth.suprnova.cc/index.php?page=gettingstarted
http://ubiq.suprnova.cc/index.php?page=gettingstarted
http://exp.suprnova.cc/index.php?page=gettingstarted
http://dcr.suprnova.cc/index.php?page=gettingstarted
http://chc.suprnova.cc/index.php?page=gettingstarted
https://dem.suprnova.cc/index.php?page=gettingstarted
http://sib.suprnova.cc/index.php?page=gettingstarted
http://erc.suprnova.cc/index.php?page=gettingstarted
http://hodl.suprnova.cc/index.php?page=gettingstarted
http://mona.suprnova.cc/index.php?page=gettingstarted
http://grs.suprnova.cc/index.php?page=gettingstarted
http://myrgrs.suprnova.cc/index.php?page=gettingstarted
http://dgbg.suprnova.cc/index.php?page=gettingstarted
http://dgbq.suprnova.cc/index.php?page=gettingstarted
http://dgbs.suprnova.cc/index.php?page=gettingstarted
http://gmc.suprnova.cc/index.php?page=gettingstarted
http://spr.suprnova.cc/index.php?page=gettingstarted
http://start.suprnova.cc/index.php?page=gettingstarted
https://flo.suprnova.cc/index.php?page=gettingstarted
http://geo.suprnova.cc/index.php?page=gettingstarted
http://ltc.suprnova.cc/index.php?page=gettingstarted
http://xmg.suprnova.cc/index.php?page=gettingstarted
	)

for webp in ${webpage[@]}; do
    w3m -dump $webp >>suprnova.ccminer
done
grep ccminer suprnova.ccminer
