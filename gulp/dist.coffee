runSequence = require 'run-sequence'

module.exports = (gulp) ->

  gulp.task 'dist', (next) ->
    runSequence 'build', 'dist:copy', next

  gulp.task 'dist:copy', ->
    gulp.src([
      'build/dist/eventric.js'
      'build/dist/eventric-min.js'
    ])
      .pipe(gulp.dest('dist/'))
