window.template_cache = {};
window.map_poller = {};

function template(name) {
  if (window.template_cache[name] == undefined) {
    window.template_cache[name] = Mustache.compile($('#template-'+name).html());
  }
  return window.template_cache[name];
}

$(document).ready(function () {
  $('body').delegate('#tabs a', 'click', tab_clicked);
  $('body').delegate('a[href="#memory-usage"]', 'click', memory_usage);
  $('body').delegate('a[href="#stats"]', 'click', stats);

  $.get('/servers.json', function (data) {
    window.servers = {};
    $(data).each(function () {
      window.servers[this.name] = this;
      $('#tabs').append(template("tab")(this));
      $('body').append(template("server")(this));
      fill_stats();
    })

    var name = location.pathname.split('/')[1];
    if (name == "") {
      name = data[0].name;
    }

    if (data.length > 0) {
      $('a[data-name="' + name + '"]').click();
    }

    // poller for stat updates (10 sn interval)
    setInterval(function () {
      $.get('/servers.json', function (data) {
        $(data).each(function () {
          window.servers[this.name] = this;
        });
        fill_stats();
      });
    }, 10000);
  },'json');
});

function tab_clicked(){
  var $tab = $(this),
      name = $tab.data('name'),
      server = window.servers[name];
  $('#tabs li').removeClass('selected');
  $tab.closest('li').addClass('selected');
  $('.server').hide();
  $('#server-' + name).show();
  $('.server .visible a[href="stats"]').click();
  history.pushState({}, null, "/" + name );
  return false;
}

function fill_stats() {
  for(name in window.servers) {
    server = window.servers[name];
    context = $('#server-'+name);
    $('.stats ul', context).children().remove();
    if (server.usage != null) {
      $(".stats ul", context).append(template("usage")(server.usage));
    }

    for(key in server.info) {
      if (server.fields.indexOf(key) != -1) {
        $(".stats ul",context).append(template("stat")({ key: key, value: server.info[key] }));
      }
    }
  }
}

function stats() {
  var context = $(this).closest('.server');
  $('.panel', context).hide();
  $('.stats', context).show();
  return false;
}

function fill_memory_usage(name) {
  var context = $("#server-" + name);
  $(".memory-usage", context).children().remove();
  d3.json("/" + name + "/stats.json", function(error, root) {
    if (error !== null) {
      console.log(error);
      $('.memory-usage', context).append(template('error')(error));
    } else {
      if (root.status) {
        clearInterval(window.map_poller[name]);
        var margin = {top: 40, right: 10, bottom: 10, left: 10},
          width = 960 - margin.left - margin.right,
          height = 500 - margin.top - margin.bottom;

        var color = d3.scale.category20c();

        var treemap = d3.layout.treemap()
            .size([width, height])
            .sticky(true)
            .value(function(d) { return d.size; });

        var div = d3.select("#server-" + name +" .memory-usage").append("div")
            .style("position", "relative")
            .style("width", (width + margin.left + margin.right) + "px")
            .style("height", (height + margin.top + margin.bottom) + "px")
            .style("left", margin.left + "px")
            .style("top", margin.top + "px");

        var node = div.datum(root).selectAll(".node")
          .data(treemap.nodes)
        .enter().append("div")
          .attr("class", "node")
          .call(position)
          .style("background", function(d) { return d.children ? color(d.name) : null; })
          .text(function(d) { return d.name; });

      } else {
        // Loading
        $('.memory-usage', context).append('<h1 class="loading">Loading...</h1>')
        if (window.map_poller[name] == undefined) {
          window.map_poller[name] = setInterval(function () {
            fill_memory_usage(name);
          }, 5000);
        }
      }
    }
  });

  function position() {
    this.style("left", function(d) { return d.x + "px"; })
        .style("top", function(d) { return d.y + "px"; })
        .style("width", function(d) { return Math.max(0, d.dx - 1) + "px"; })
        .style("height", function(d) { return Math.max(0, d.dy - 1) + "px"; });
  }
}

function memory_usage() {
  var context = $(this).closest('.server'),
      name = context.data('name');

  fill_memory_usage(name);

  $('.panel', context).hide();
  $('.memory-usage', context).show();
  return false;
}