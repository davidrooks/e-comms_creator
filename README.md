Work in progress!
====



Go!
===

Download and install mongo:
    brew install mongo
    mongod                     #start mongo database

Download and run e-comm creator:

    git clone https://github.com/davidrooks/e-comms_creator.git
    
    cd e-comms_creator
    bundle install             # To install sinatra
    
    bundle exec ruby app.rb    # To run the sample
	
Then open [http://localhost:4567/](http://localhost:4567/)

What's next?
============
- shrink image size when laying out ecomm
- snap images to a grid - http://jqueryui.com/draggable/#snap-to
- openshift integration / deployment
