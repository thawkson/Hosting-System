<?php

set_time_limit(300);

$searchdec = "Dec 2005</FONT></A></TD>
<TD ALIGN=right><FONT SIZE=\"-1\">([0-9]+)</FONT></TD>
<TD ALIGN=right><FONT SIZE=\"-1\">([0-9]+)</FONT></TD>
<TD ALIGN=right><FONT SIZE=\"-1\">([0-9]+)</FONT></TD>
<TD ALIGN=right><FONT SIZE=\"-1\">([0-9]+)</FONT></TD>
<TD ALIGN=right><FONT SIZE=\"-1\">([0-9]+)</FONT></TD>
<TD ALIGN=right><FONT SIZE=\"-1\">([0-9]+)</FONT></TD>
<TD ALIGN=right><FONT SIZE=\"-1\">([0-9]+)</FONT></TD>
<TD ALIGN=right><FONT SIZE=\"-1\">([0-9]+)</FONT></TD>
<TD ALIGN=right><FONT SIZE=\"-1\">([0-9]+)</FONT></TD>
<TD ALIGN=right><FONT SIZE=\"-1\">([0-9]+)</FONT></TD></TR>";

$searchjan = "Jan 2006</FONT></A></TD>
<TD ALIGN=right><FONT SIZE=\"-1\">([0-9]+)</FONT></TD>
<TD ALIGN=right><FONT SIZE=\"-1\">([0-9]+)</FONT></TD>
<TD ALIGN=right><FONT SIZE=\"-1\">([0-9]+)</FONT></TD>
<TD ALIGN=right><FONT SIZE=\"-1\">([0-9]+)</FONT></TD>
<TD ALIGN=right><FONT SIZE=\"-1\">([0-9]+)</FONT></TD>
<TD ALIGN=right><FONT SIZE=\"-1\">([0-9]+)</FONT></TD>
<TD ALIGN=right><FONT SIZE=\"-1\">([0-9]+)</FONT></TD>
<TD ALIGN=right><FONT SIZE=\"-1\">([0-9]+)</FONT></TD>";

$searchfeb = "Feb 2006</FONT></A></TD>
<TD ALIGN=right><FONT SIZE=\"-1\">([0-9]+)</FONT></TD>
<TD ALIGN=right><FONT SIZE=\"-1\">([0-9]+)</FONT></TD>
<TD ALIGN=right><FONT SIZE=\"-1\">([0-9]+)</FONT></TD>
<TD ALIGN=right><FONT SIZE=\"-1\">([0-9]+)</FONT></TD>
<TD ALIGN=right><FONT SIZE=\"-1\">([0-9]+)</FONT></TD>
<TD ALIGN=right><FONT SIZE=\"-1\">([0-9]+)</FONT></TD>
<TD ALIGN=right><FONT SIZE=\"-1\">([0-9]+)</FONT></TD>
<TD ALIGN=right><FONT SIZE=\"-1\">([0-9]+)</FONT></TD>";

print "<pre>";

print str_pad("VIRTUAL HOST", 50, " ", STR_PAD_RIGHT);
print str_pad("DEC 2005", 16, " ", STR_PAD_LEFT);
print str_pad("JAN 2006", 16, " ", STR_PAD_LEFT);
print str_pad("FEB 2006", 16, " ", STR_PAD_LEFT);
print "\n";
print str_repeat("-", 120);
print "\n";

$count = 0;


$totaldec = 0;
$totaljan = 0;
$totalfeb = 0;

$d = dir("./");
while (false !== ($entry = $d->read())) {
	if (is_dir("./$entry")) {
		$piecesdec = array();
		$piecesjan = array();
		$piecesfeb = array();

		$flagdec = " ";
		$flagjan = " ";
		$flagfeb = " ";

		$filename = $entry . "/usage/index.html";
		if (file_exists($filename)) {
   			$handle = fopen($filename, "rb");
			$contents = fread($handle, filesize($filename));
			eregi($searchdec, $contents,  $piecesdec);
			eregi($searchjan, $contents,  $piecesjan);
			eregi($searchfeb, $contents,  $piecesfeb);
			$totaldec += $piecesdec[6];
			$totaljan += $piecesjan[6];
			$totalfeb += $piecesfeb[6];
			$gigsdec = (int) $piecesdec[6] / 1024 / 1024;			
			$gigsjan = (int) $piecesjan[6] / 1024 / 1024;
			$gigsfeb = (int) $piecesfeb[6] / 1024 / 1024;
			if ($gigsdec > 1) $flagdec = "*";
			if ($gigsjan > 1) $flagjan = "*";
			if ($gigsfeb > 1) $flagfeb = "*";
			print str_pad($entry, 50, " ", STR_PAD_RIGHT);
			print str_pad(round($gigsdec, 3) . " GB", 15, " ", STR_PAD_LEFT) . $flagdec;
			print str_pad(round($gigsjan, 3) . " GB", 15, " ", STR_PAD_LEFT) . $flagjan;
			print str_pad(round($gigsfeb, 3) . " GB", 15, " ", STR_PAD_LEFT) . $flagfeb;
			print "\n";
			$count++;
		}
	}
}
$d->close();

// Totals:

print str_pad("MONTHLY TOTAL:", 50, " ", STR_PAD_LEFT);
print str_pad(round($totaldec / 1024 /1024, 3) . " GB", 16, " ", STR_PAD_LEFT);
print str_pad(round($totaljan / 1024 /1024, 3) . " GB", 16, " ", STR_PAD_LEFT);
print str_pad(round($totalfeb / 1024 /1024, 3) . " GB", 16, " ", STR_PAD_LEFT);
print "</pre>";
print "\n\nTOTAL HOSTS: $count";
?>
