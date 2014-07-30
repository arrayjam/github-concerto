var github = require("octonode");

require("dotenv").load();

var login = "arrayjam";

var client = github.client(process.env.GITHUB_PERSONAL_ACCESS_TOKEN);

var ghuser = client.user(login);

ghuser.events({}, 20, ["CreateEvent"], function() {
  console.log(arguments);
});
//var eventsEndpoint = "/users/" + login + "/events";
//client.get(eventsEndpoint, {}, function (err, status, body, headers) {
  //console.log(headers, body); //json object
//});
