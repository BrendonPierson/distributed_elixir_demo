start_child = fn name -> %DD.Child{name: name, start: {DD.ExampleChild, :start_link, [name]}} end
