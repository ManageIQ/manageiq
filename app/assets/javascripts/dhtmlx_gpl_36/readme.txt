dhtmlxSuite 2013 Rel.1 (DHTMLX 3.6)  Standard edition build 131108

These components are allowed to use under GPL or you need to obtain Commercial or Enterise License
to use them in not GPL project. PLease contact sales@dhtmlx.com for details

(c) DHTMLX Ltd. 


USER NOTES:

Activation Key 
---------------

You do not need any activation key. Just unzip the package and it is ready for use.


Package Content
---------------

dhtmlxSuite package contains common documentation and samples browser for all components included. To open it just load index.html from the root of the package. It's better run it this from a web server, cause some samples requires http connection and some PHP (though not really many of them).

Directory structure:

To start with some component please go down to its folder within the package. For example dhtmlxGrid.

- "codebase" folder contains all stuff you need to work with grid. Javascript (.js) and style (.css) files in the root of codebase is a minimum set of files you need to start. 
	- codebase/ext - extensions of basic functionality (basic is also quite wide) are in ext folder within "codebase".
	- codebase/excells - additional cell editors are in  excels folder under "codebase". 
	- codebase/imgs - contains images which are necessary for component to work - like down and up arrows for sorting, images for some included cell editors, skins related images. 

So, "codebase" folder contains all you need to use component. 

- "sources". This folder contains same js files which are in "codebase", but not compressed and with kept comments. These files can be useful if you need to make your own modifications in original code. 

- "doc" and "samples" folders contain documentation and samples files.

If you need to use more than one component in your application you can put files from their codebase folders into one. The only conflict can be with dhtmlxcommon.js file, as it is included in all components. Do not hesitate  to overwrite them, just make sure you keep the one which is most recent (this is important when you get component updates. Originally dhtmlxcommon.js is the same in all components codebase folders).

Library Compilation
--------------------

You can use compilation of entire DHTMLX Library available as dhtmlx_std_full.zip (find it in the root of the package). All components, extensions and styles are combined there within dhtmlx.js, dhtmlx.css and folder with necessary images. Although it's unlikely that all available extensions will be used in a single application, it's still a good and fast way to start developing with DHTMLX. On production stage, you can leave only required components/extensions/functionality and minimize dhtmlx.js file size with the help of libCompiler (see below).



Create Single File Library with libCompiler (beta. requires PHP)
----------------------------------------------------------------

dhtmlxSuite contains the tool which can combine numerous script files of DHTMLX library into a single JS file (+ single CSS file) depending on chosen functionality. 
To use this tool, you need to unzip dhtmlxSuite package content into directory under web server with support for PHP and load [dhtmlxSuitePackage]/libCompiler/index.html. Currently there is no difference between libCompiler delivered with Standard and Professional Editions of dhtmlxSuite, but resulting files functionality depends on Edition of course.
More details about usage of libCompiler can be found here: http://docs.dhtmlx.com/doku.php?id=others:toc_libcompiler



We hope you enjoy working with dhtmlx components!

Best Regards,
dhtmlx team.