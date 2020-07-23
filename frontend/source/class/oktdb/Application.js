/* ************************************************************************
   Copyright: 2020 Tobias Oetiker
   License:   ???
   Authors:   Tobias Oetiker <tobi@oetiker.ch>
 *********************************************************************** */

/**
 * Main application class.
 * @asset(oktdb/*)
 *
 */
qx.Class.define("oktdb.Application", {
    extend : callbackery.Application,
    members : {
        main : function() {
            // Call super class
            this.base(arguments);
        }
    }
});
