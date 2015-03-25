foreach { flow project revision } $quartus(args) { break }

set file_name ${project}.qpf

if { [catch {exec ./generate} msg] } {
	post_message "Failed to generate files."
}
