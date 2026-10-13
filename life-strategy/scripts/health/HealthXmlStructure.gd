extends RefCounted

## XMLParser is a token reader. Check document boundaries before either health
## loader accepts records; semantic fields remain the validators' responsibility.
static func validate(buffer: PackedByteArray) -> String:
	var parser := XMLParser.new()
	if parser.open_buffer(buffer) != OK:
		return "XML buffer could not be opened."
	var stack: Array[String] = []
	var root_count := 0
	var previous_offset := -1
	var read_error := parser.read()
	while read_error == OK:
		var offset := parser.get_node_offset()
		if offset <= previous_offset:
			return "XML parser did not advance to a new node."
		previous_offset = offset
		match parser.get_node_type():
			XMLParser.NODE_ELEMENT:
				if stack.is_empty():
					root_count += 1
					if root_count > 1:
						return "XML document contains more than one root."
				if not parser.is_empty():
					stack.append(parser.get_node_name())
			XMLParser.NODE_ELEMENT_END:
				if stack.is_empty() or stack.back() != parser.get_node_name():
					return "XML closing element does not match its opening element."
				stack.pop_back()
			XMLParser.NODE_TEXT:
				if stack.is_empty() and not parser.get_node_data().strip_edges().is_empty():
					return "XML document contains text outside its root."
			XMLParser.NODE_CDATA:
				if stack.is_empty():
					return "XML document contains CDATA outside its root."
		read_error = parser.read()
	if read_error != ERR_FILE_EOF:
		return "XML token could not be parsed (error %d)." % read_error
	if root_count != 1 or not stack.is_empty():
		return "XML document has a missing or unclosed root/element."
	return ""
